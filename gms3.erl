-module(gms3).
-define(arghh, 10).
-export([start/1, start/2]).

start(Id) ->
    Rng = random:uniform(1000),
    Self = self(),
    {ok, spawn_link(fun() -> init(Id, Self, Rng) end)}.

start(Id, Grp) ->
    Rng = random:uniform(1000),
    Self = self(),
    {ok, spawn_link(fun() -> init(Id, Grp, Self, Rng) end)}.

init(Id, Grp, Master, Rng) ->
    random:seed(Rng, Rng, Rng),
    Self = self(),
    Grp ! {join, Master, Self},
    Timeout = 50,
    receive
        {view, N, [Leader|Slaves], Group} ->
            erlang:monitor(process, Leader),
            Master ! {view, Group},
            slave(Id, Master, Leader, N, {view, N, [Leader|Slaves], Group}, Slaves, Group)
        after Timeout -> 
            Master ! {error, "No reply from leader"}
    end.

init(Id, Master, Rng) ->
    random:seed(Rng, Rng, Rng),
    io:format("first leader: ~w~n", [self()]),
    leader(Id, Master, 0, [], [Master]).

leader(Id, Master, N, Slaves, Group) ->
    io:format("lead: ~w~n", [Id]),
    receive
        {mcast, Msg} ->
            bcast(Id, {msg, N + 1, Msg}, Slaves),
            Master ! Msg,
            leader(Id, Master, N + 1, Slaves, Group);
        {join, Wrk, Peer} ->
            Slaves2 = lists:append(Slaves, [Peer]),
            Group2 = lists:append(Group, [Wrk]),
            bcast(Id, {view, N + 1, [self()|Slaves2], Group2}, Slaves2),
            Master ! {view, [self()|Slaves2]},
            leader(Id, Master, N + 1, Slaves2, Group2);
        alive ->
            Master ! i_am_alive,
            leader(Id, Master, N, Slaves, Group);
        stop ->
            ok
    end.    

bcast(Id, Msg, Slaves) ->
    crash(Id),
    lists:foreach(fun(X) -> X ! Msg end, Slaves).

crash(Id) ->
    case random:uniform(?arghh) of
        ?arghh ->
            io:format("leader ~w: crash ~n", [Id]),
            exit(no_luck);
        _ ->
            ok
    end. 

slave(Id, Master, Leader, N, Last, Slaves, Group) ->
    receive 
        {mcast, Msg} ->
            Leader ! {mcast, Msg},
            slave(Id, Master, Leader, N, Last, Slaves, Group);
        {join, Wrk, Peer} ->
            Leader ! {join, Wrk, Peer},
            slave(Id, Master, Leader, N, Last, Slaves, Group);
        {msg, I, Msg} when I =< N ->
                slave(Id, Master, Leader, N, Last, Slaves, Group);
        {msg, I, Msg} ->
            Master ! Msg,
            slave(Id, Master, Leader, I, Last, Slaves, Group);
        {view, I, [Leader|Slaves2], Group2} when I =< N ->
            slave(Id, Master, Leader, N, Last, Slaves2, Group2);
        {view, I, [Leader|Slaves2], Group2} ->
            Master ! {view, Group2},
            slave(Id, Master, Leader, N, Last, Slaves2, Group2);
        {'DOWN', _Ref, process, Leader, _Reason} ->
            election(Id, Master, N, Last, Slaves, Group);
        leader -> 
            io:format("current leader: ~w", [Leader]),
            slave(Id, Master, Leader, N, Last, Slaves, Group);            
        stop ->
            ok
    end.

election(Id, Master, N, Last, Slaves, [_|Group]) ->
    Self = self(),
    case Slaves of
        [Self|Rest] ->
            bcast(Id, Last, Rest),
            bcast(Id, {view, N + 1, [Self|Slaves], Group}, Rest),
            Master ! {view, Group},
            io:format("New leader: ~w, With Pid: ~w, Slaves left: ~w~n", [Id, self(), Rest]),
            leader(Id, Master, N + 1, Rest, Group);
        [Leader|Rest] ->
            erlang:monitor(process, Leader),
            io:format("Turning into a slave again: ~w~n", [Id]),
            slave(Id, Master, Leader, N, Last, Rest, Group)
    end.
