Seg_MSG_IA_02_2_19 = {'MSG', [
  %% List of elements
  {<<"messageFunctionDetails">>, 'cond', 1, [
    %% List of compounds
    {<<"businessFunction">>, 'mand', 1, 'aln', 0, 3},
    {<<"messageFunction">>, 'cond', 1, 'aln', 0, 3},
    {<<>>, 'cond', 1, 'aln', 0, 0},
    {<<"additionalMessageFunction">>, 'cond', 2, 'aln', 0, 3}
  ]}
]},
Seg_ORG_IA_07_1_2 =  {'ORG', [
  {<<"deliveringSystem">>, 'cond', 1, [
    {<<"companyId">>, 'cond', 1, 'aln', 0, 35},
    {<<"locationId">>, 'cond', 1, 'aln', 0, 25},
    {<<"location">>, 'cond', 1, 'aln', 0, 17}
  ]},
  {<<"originIdentification">>, 'cond', 1, [
    {<<"originatorId">>, 'cond', 1, 'aln', 0, 9},
    {<<"inHouseIdentification1">>, 'cond', 1, 'aln', 0, 9}
  ]}
]},
Seg_MSG_IA_02_2_3 =  {'MSG', []},
Seg_STX_IA_02_2_1 =  {'STX', []},
Seg_ODI_IA_02_2_3 =  {'ODI', []},
Seg_DUM_IA_01_2_1 =  {'DUM', []},
Seg_TVL_IA_02_2_12 = {'TVL', [
  {<<"flightDate">>, 'cond', 1, [
    {<<"departureDate">>, 'cond', 1, 'num', 6, 6},
    {<<"departureTime">>, 'cond', 1, 'num', 4, 4},
    {<<"arrivalDate">>, 'cond', 1, 'num', 6, 6},
    {<<"arrivalTime">>, 'cond', 1, 'num', 4, 4}
  ]},
  {<<"boardPointDetails">>, 'cond', 1, [
    {<<"trueLocationId">>, 'cond', 1, 'aln', 0, 3}
  ]},
  {<<"offPointDetails">>, 'cond' , 1, [
    {<<"trueLocationId">>, 'cond', 1, 'aln', 0, 3}
  ]},
  {<<"companyDetails">>, 'cond', 1, [
    {<<"marketingCompany">>, 'cond', 1, 'aln', 0, 3},
    {<<"operatingCompany">>, 'cond', 1, 'aln', 0, 3},
    {<<"otherCompany">>, 'cond', 1, 'aln', 0, 35}
  ]},
  {<<"flightIdentification">>, 'cond' , 1, [
    {<<"flightNumber">>, 'mand', 1, 'num', 0, 4},
    {<<>>, 'cond', 1, 'aln', 0, 0},
    {<<"operationalSuffix">>, 'cond', 1, 'aln', 1, 1}
  ]},
  {<<"flightTypeDetails">>, 'cond', 1, [
    {<<"solutionNumber">>, 'mand', 1, 'aln', 0, 6}
  ]},
  {<<"itemNumber">>, 'cond', 1, 'num', 0, 2},
  {<<"flightIndicator">>, 'cond', 12, 'aln', 0, 3}
]},
[
  {{'UNB', []}, <<>>, 'mand', 1},
  {{'UNH', []}, <<>>, 'mand', 1},
  {Seg_MSG_IA_02_2_19, <<"messageEntry">>, 'cond', 1},
  {Seg_ORG_IA_07_1_2, <<"originatorDetails">>, 'cond', 1},
  {<<"availabilityGroup">>, 'mand', 9, [
    {Seg_MSG_IA_02_2_3, <<"messageOptions">>, 'mand', 1},
    {Seg_STX_IA_02_2_1, <<"neutralTriggerIndicator">>, 'cond', 1},
    {<<"availabilityBoardOffGroup">>, 'cond', 5000, [
      {Seg_ODI_IA_02_2_3, <<"boardOff">>, 'mand', 1},
      {<<"solutionGroup">>, 'cond', 99, [
        {Seg_DUM_IA_01_2_1, <<"dummySegment">>, 'mand', 1},
        {Seg_TVL_IA_02_2_12, <<"flightInfo">>, 'cond', 5000}
      ]}
    ]}
  ]},
  {{'UNT', []}, <<>>, 'mand', 1},
  {{'UNZ', []}, <<>>, 'mand', 1}
].
