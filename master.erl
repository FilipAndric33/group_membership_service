-module(master).

-export([start_leader/0, start_slave/2]).

start_leader() ->
    init(1).

start_slave(Id, Grp) ->
    add(Id, Grp).

init(Id) ->
    leader:start(Id).

add(Id, Grp) ->
    slaves:start(Id, Grp).

