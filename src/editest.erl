%% compile:file(editest, [native, {hipe, [o3,verbose,load]}]).

-module(editest).
-export([start/0, bench/2, bench2/1]).

%% ----------------------------------------------------------------------------

file_to_value(File) ->
  {ok, Data} = file:read_file(File),
  String = binary_to_list(Data),
  {ok, Tokens, _} = erl_scan:string(String),
  {ok, Exprs} = erl_parse:parse_exprs(Tokens),
  {value, Value, _} = erl_eval:exprs(Exprs, []),
  Value.

start() ->
  Spec = file_to_value("edispec.erl"),
  {ok, Data} = file:read_file("AFIVRQ.edi"),
  Message = parse(Spec, Data),
  Stream = term_to_binary(Message),
  io:format("Start~n", []),
  {Time, _} = timer:tc(editest, bench2, [Stream]),
  %%Message = parse(Spec, Data),
  %%io:format("Message ~p~n", [Message]).
  io:format("End ~p~n", [Time]).

%% ----------------------------------------------------------------------------
%% Parse a stream of bytes as an list of EDIFACT segments
%% ----------------------------------------------------------------------------

-define(SSEP, $').
-define(DSEP, $+).
-define(CSEP, $:).

%% Composite strings are kept in reverse order.
%% It is up to the concrete message decoder to reverse them if needed.

%% Entry point.
parse_string(String) ->
  parse_string_seg(String, [], []).

%% Final point.
parse_string_seg( [], Segments, [] ) ->
  {ok, lists:reverse(Segments)};

%% Match a segment separator => Insert an empty segment.
parse_string_seg( [?SSEP|NextChars],
                  Segments, Tag ) ->
  NewTag = list_to_atom(lists:reverse(Tag)),
  NewSegments = [{NewTag, []}|Segments],
  parse_string_seg(NextChars, NewSegments, []);

%% Match a data element separator => Switch to the compound state.
parse_string_seg( [?DSEP|NextChars],
                  Segments, Tag ) ->
  parse_string_cpd(NextChars, Segments, Tag, [], [], {num, 0, []});

%% Match a character part of the segment name.
parse_string_seg( [Char|NextChars],
                  Segments, Tag ) ->
  parse_string_seg(NextChars, Segments, [Char|Tag]).

%% Match a segment separator => Finalize pending compound, element and segment.
parse_string_cpd( [?SSEP|NextChars],
                  Segments, Tag, Elements, Compounds, Compound ) ->
  NewCompounds = lists:reverse([Compound|Compounds]),
  NewElements = lists:reverse([NewCompounds|Elements]),
  NewTag = list_to_atom(lists:reverse(Tag)),
  NewSegments = [{NewTag, NewElements}|Segments],
  parse_string_seg(NextChars, NewSegments, []);

%% Match a data element separator => Finalize pending compound and element.
parse_string_cpd( [?DSEP|NextChars],
                  Segments, Tag, Elements, Compounds, Compound ) ->
  NewCompounds = lists:reverse([Compound|Compounds]),
  NewElements = [NewCompounds|Elements],
  parse_string_cpd(NextChars, Segments, Tag, NewElements, [], {num, 0, []});

%% Match a compound separator => Finalize pending compound.
parse_string_cpd( [?CSEP|NextChars],
                  Segments, Tag, Elements, Compounds, Compound ) ->
  NewCompounds = [Compound|Compounds],
  parse_string_cpd(NextChars, Segments, Tag, Elements, NewCompounds, {num, 0, []});

%% Match a numeric character => Append to the current compound.
parse_string_cpd( [Char|NextChars],
                  Segments, Tag, Elements, Compounds,
                  {num, Length, Chars} ) when (Char >= $0) and (Char =< $9) ->
  parse_string_cpd(NextChars, Segments, Tag, Elements, Compounds, {num, Length+1, [Char|Chars]});

%% Match an alpha-numeric character => Append to the current compound.
parse_string_cpd( [Char|NextChars],
                  Segments, Tag, Elements, Compounds,
                  {_, Length, Chars} ) ->
  parse_string_cpd(NextChars, Segments, Tag, Elements, Compounds, {aln, Length+1, [Char|Chars]}).

%% ----------------------------------------------------------------------------
%% Parse a list of composites against an EDIFACT specification
%% ----------------------------------------------------------------------------

%% Entry point.
parse_composites(Spec, Composites) ->
  parse_composites(Spec, Composites, []).

%% Final point.
parse_composites([], [], SubRecords) ->
  SubRecords;

%% Match end of spec with remaining data.
parse_composites([], _, SubRecords) ->
  ['garbage' | SubRecords];

%% Skip a conditional spec when the input stream is exhausted.
parse_composites([{_, 'cond', _, _, _, _} | NextSpecs], Composites=[], SubRecords) ->
  parse_composites(NextSpecs, Composites, SubRecords);

%% Jump to composite parsing loop.
parse_composites([{Name, _, Cardinality, Type, Min, Max} | NextSpecs], Composites, SubRecords) ->
  parse_composites_cps(Cardinality, Type, Min, Max, Name, NextSpecs, Composites, SubRecords).

%% Match the end of the cardinality loop.
parse_composites_cps(0, _, _, _, _, NextSpecs, Composites, SubRecords) ->
  parse_composites(NextSpecs, Composites, SubRecords);

%% Append a composite matching the spec to the list of records.
parse_composites_cps(Cardinality, SType, Min, Max, Name, NextSpecs,
                     [{DType, Length, Data} | NextComposites], SubRecords)
  when (Length >= Min) and (Length =< Max) and ((SType =:= 'aln') or (SType =:= DType)) ->
  NewSubRecords = [{Name, lists:reverse(Data)} | SubRecords],
  parse_composites_cps(Cardinality-1, 'cond', Min, Max, Name, NextSpecs, NextComposites, NewSubRecords).

%% ----------------------------------------------------------------------------
%% Parse a list of data elements against an EDIFACT specification
%% ----------------------------------------------------------------------------

%% Entry point.
parse_elements(Spec, Elements) ->
  parse_elements(Spec, Elements, []).

%% Final point.
parse_elements([], [], Records) ->
  Records;

%% Match end of spec with remaining data.
parse_elements([], _, Records) ->
  ['garbage' | Records];

%% Skip a conditional spec when the input stream is exhausted.
parse_elements([{_, 'cond', _, _} | NextSpecs], Elements=[], Records) ->
  parse_elements(NextSpecs, Elements, Records);

%% Jump to compound parsing loop.
parse_elements([{Name, _, Cardinality, CompoundSpec} | NextSpecs], Elements, Records) ->
  parse_elements_cpd(Cardinality, Name, CompoundSpec, NextSpecs, Elements, Records);

%% Skip a conditional spec when the input stream is exhausted.
parse_elements([{_, 'cond', _, _, _, _} | NextSpecs], Elements=[], Records) ->
  parse_elements(NextSpecs, Elements, Records);

%% Parse a single data element.
parse_elements([Spec | NextSpecs],
               [Element | NextElements],
               Records) ->
  [Record] = parse_composites([Spec], Element),
  NewRecords = [Record | Records],
  parse_elements(NextSpecs, NextElements, NewRecords).

%% Match the end of the cardinality loop.
parse_elements_cpd(0, _, _, NextSpecs, Elements, Records) ->
  parse_elements(NextSpecs, Elements, Records);

%% Append a data element matching the spec to the list of records.
parse_elements_cpd(Cardinality, Name, CompoundSpec, NextSpecs, [Element | NextElements], Records) ->
  RecordData = parse_composites(CompoundSpec, Element),
  NewRecords = [{Name, RecordData} | Records],
  parse_elements_cpd(Cardinality-1, Name, CompoundSpec, NextSpecs, NextElements, NewRecords).

%% ----------------------------------------------------------------------------
%% Parse a list of segments against an EDIFACT specification
%% ----------------------------------------------------------------------------

%% Entry point.
parse_segments(Spec, Segments) ->
  {ok, Message, []} = parse_segments(Spec, Segments, []),
  {ok, Message}.

%% Final point.
parse_segments( [], Segments, Message ) ->
  {ok, lists:reverse(Message), Segments};

%% Match a segment definition.
parse_segments( [{{Tag, SegmentSpec}, Name, Type, Cardinality} | NextSpecs],
                Segments, Message ) ->
  parse_segments_seg(Tag, Type, Cardinality, Name, SegmentSpec, NextSpecs, Segments, Message );

%% Match a group definition.
parse_segments( [{Name, Type, Cardinality, GroupSpec=[{{Tag,_},_,_,_}|_]} | NextSpecs],
                Segments, Message ) ->
  parse_segments_grp(Tag, Type, Cardinality, Name, GroupSpec, NextSpecs, Segments, Message ).

%% Skip a branch when the cardinality is exhausted.
parse_segments_seg( _, _, 0, _, _, NextSpecs, Segments, Message ) ->
  parse_segments(NextSpecs, Segments, Message);

%% Match a branch having the same tag as the current segment.
parse_segments_seg( Tag, _, Cardinality, Name, SegmentSpec, NextSpecs,
                    [{Tag, Elements} | NextSegments],
                    Message ) ->
  Record = {Name, parse_elements(SegmentSpec, Elements)},
  NewMessage = [Record | Message],
  parse_segments_seg(Tag, 'cond', Cardinality-1, Name, SegmentSpec, NextSpecs, NextSegments, NewMessage);

%% Skip a non-matching branch if it is conditional.
parse_segments_seg( _, 'cond', _, _, _, NextSpecs, Segments, Message ) ->
  parse_segments(NextSpecs, Segments, Message).

%% Skip a sub-branch when the cardinality is exhausted.
parse_segments_grp( _, _, 0, _, _, NextSpecs, Segments, Message ) ->
  parse_segments(NextSpecs, Segments, Message);

%% Match a sub-branch having the same tag as the current segment.
parse_segments_grp( Tag, _, Cardinality, Name, GroupSpec, NextSpecs,
                    Segments=[{Tag, _} | _],
                    Message ) ->
  {ok, SubMessage, NewSegments} = parse_segments(GroupSpec, Segments, []),
  Record = {Name, SubMessage},
  NewMessage = [Record | Message],
  parse_segments_grp(Tag, 'cond', Cardinality-1, Name, GroupSpec, NextSpecs, NewSegments, NewMessage);

%% Skip a non-matching sub-branch if it is conditional.
parse_segments_grp( _, 'cond', _, _, _, NextSpecs, Segments, Message ) ->
  parse_segments(NextSpecs, Segments, Message).

%% ----------------------------------------------------------------------------

parse(Spec, Data) ->
  String = binary_to_list(Data),
  {ok, Segments} = parse_string(String),
  {ok, Message} = parse_segments(Spec, Segments),
  Message.

%% ----------------------------------------------------------------------------

bench(Spec, Data) ->
  bench(Spec, Data, 0).

bench(Spec, Data, 1000) ->
  _Message = parse(Spec, Data);
  %%io:format("Message ~p~n", [_Message]);
bench(Spec, Data, N) ->
  parse(Spec, Data),
  bench(Spec, Data, N+1).

%% ----------------------------------------------------------------------------

bench2(Data) ->
  bench2(Data, 0).

bench2(Data, 1000) ->
  _Message = binary_to_term(Data);
  %%io:format("Message ~p~n", [_Message]);
bench2(Data, N) ->
  _Message = binary_to_term(Data),
  bench2(Data, N+1).
