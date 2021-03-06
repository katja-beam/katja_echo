%%%-------------------------------------------------------------------
%% @private
%% @doc Module for scanner and parsing a Riemann Query.
%% @end
%%%-------------------------------------------------------------------

-module(katja_echo_query).

-include_lib("stdlib/include/qlc.hrl").
-include("katja_echo_pb.hrl").

-include_lib("eunit/include/eunit.hrl").

-export([parse/1, query/2]).


parse(<<Bin/binary>>) ->
    parse(binary_to_list(Bin));

parse(String) ->
    {ok, Tokens, _EndLine} = katja_echo_query_lexer:string(String),
    katja_echo_query_grammar:parse(Tokens).


query(Tab, P) ->
    {ok, qq(Tab, P, [])}.

% build match spec

do_query(Tab, MatchConditions) ->
    MS = [{{'_', '$1'}, MatchConditions, ['$1']}],
    {ok, ets:select(Tab, MS)}.


qq(_Tab, [], R) ->
    R;

qq(Tab, [{'and', P} | Hs], R) ->
    {ok, Results} = do_query(Tab, make_match_conditions('andalso', Tab, P)),
    qq(Tab, Hs, Results ++ R);

qq(Tab, [{'or', P} | Hs], R) ->
    {ok, Results} = do_query(Tab, make_match_conditions('orelse', Tab, P)),
    qq(Tab, Hs, Results ++ R);

qq(Tab, [{field, _, _, _} = P | [] = Hs], R) ->
    {ok, Results} = do_query(Tab, make_match_conditions('andalso', Tab, P)),
    qq(Tab, Hs, Results ++ R);

qq(Tab, [{field, _, _, _} = P | Hs], R) ->
    qq(Tab, Hs, make_match_conditions('andalso', Tab, P) ++ R);

qq(Tab, [{field, _, _} = P | Hs], R) ->
    qq(Tab, Hs, make_match_conditions('andalso', Tab, P) ++ R).


make_match_conditions(Op, Tab, P) when is_list(P) ->
    [list_to_tuple([Op | q(Tab, P, [])])];

make_match_conditions(Op, Tab, P) ->
    make_match_conditions(Op, Tab, [P]).


q(_Tab, [], R) ->
    R;

q(Tab, [{'and', Q} | Hs], R) ->
    qq(Tab, Hs, [ q(Tab, Q, R) ]);

q(Tab, [{'or', Q} | Hs], R) ->
    qq(Tab, Hs, [ q(Tab, Q, R) ]);

q(Tab, [{field, time, Op, Time} | Hs], R) ->
    q(Tab, Hs, [{Op, {element, 2, '$1'}, {const, Time}} | R]);

q(Tab, [{field, state, Op, State} | Hs], R) ->
    q(Tab, Hs, [{Op, {element, 3, '$1'}, {const, State}} | R]);

q(Tab, [{field, service, Op, Service} | Hs], R) ->
    q(Tab, Hs, [{Op, {element, 4, '$1'}, {const, Service}} | R]);

q(Tab, [{field, host, Op, Host} | Hs], R) ->
    q(Tab, Hs, [{Op, {element, 5, '$1'}, {const, Host}} | R]);

q(Tab, [{field, description, Op, Description} | Hs], R) ->
    q(Tab, Hs, [{Op, {element, 6, '$1'}, {const, Description}} | R]);

q(Tab, [{field, tagged, Tags} | Hs], R) ->
    % tagged is a list, it is safe to use == here
    q(Tab, Hs, [{'==', {element, 7, '$1'}, {const, Tags}} | R]);

q(Tab, [{field, ttl, Op, Ttl} | Hs], R) ->
    q(Tab, Hs, [{Op, {element, 8, '$1'}, {const, Ttl}} | R]);

q(Tab, [{field, M, Op, Metric} | Hs], R) when M == metric; M == metric_d ->
    q(Tab, Hs, [{Op, {element, 12, '$1'}, {const, Metric}} | R]);

q(Tab, [{field, metric_f, Op, Metric} | Hs], R) ->
    q(Tab, Hs, [{Op, {element, 13, '$1'}, {const, Metric}} | R]).

%q(Tab, [{field, attributes, Op, Attributes} | Hs], R) ->
%    q(Tab, Hs, [{Op, {element, 9, '$1'}, {const, Attributes}} | R]);

%q(Tab, [{field, time_micros, Op, TimeMicros} | Hs], R) ->
%    q(Tab, Hs, [{Op, {element, 10, '$1'}, {const, TimeMicros}} | R]);

%q(Tab, [{field, metric_sint64, Op, Metric} | Hs], R) ->
%    q(Tab, Hs, [{Op, {element, 11, '$1'}, {const, Metric}} | R]).
