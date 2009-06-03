-module(rabbithub_app).
-behaviour(application).

-include("rabbithub.hrl").

-export([start/2,stop/1]).

start(_Type, _StartArgs) ->
    rabbithub_deps:ensure(),
    ok = contact_rabbitmq(),
    ok = setup_schema(),
    rabbithub_sup:start_link().

stop(_State) ->
    ok.

contact_rabbitmq() ->
    RabbitNode = case application:get_env(rabbitmq_node) of
                     undefined ->
                         [_NodeName, NodeHost] = string:tokens(atom_to_list(node()), "@"),
                         A = list_to_atom("rabbit@" ++ NodeHost),
                         application:set_env(rabbithub, rabbitmq_node, A),
                         A;
                     {ok, A} ->
                         A
                 end,
    {contacting_rabbitmq, pong} = {contacting_rabbitmq, net_adm:ping(RabbitNode)},
    ok.

setup_schema() ->
    case mnesia:create_schema([node()]) of
        ok -> ok;
        {error, {_, {already_exists, _}}} -> ok
    end,
    ok = mnesia:start(),
    ok = create_table(rabbithub_subscription,
                      [{attributes, record_info(fields, rabbithub_subscription)},
                       {disc_copies, [node()]}]),
    ok.

create_table(Name, Params) ->
    case mnesia:create_table(Name, Params) of
        {atomic, ok} ->
            ok;
        {aborted, {already_exists, Name}} ->
            ok
    end.