-module(gms2).
-define(arghh, 10).
-export([start/2]).

start(Id, Grp) ->
    Rng = random:uniform(1000),
    Self = self(),
    {ok, spawn_link(fun() -> init(Id, Grp, Self, Rng) end)}.

init(Id, Grp, Master, Rng) ->
    random:seed(Rng, Rng, Rng),
    Self = self(),
    if
        length(Grp) == 0 ->
            leader(Id, Master, [], [Master]);
        true -> 
            lists:foreach(fun(X) -> X ! {join, Master, Self} end, Grp),
            Timeout = 50,
            receive
                {view, [Leader|Slaves], Group} ->
                    io:format("leader: ~w~n~n", [Leader]),
                    Ref = erlang:monitor(process, Leader),
                    io:format("monitoring: ~w~n", [Ref]),
                    Master ! {view, Group},
                    slave(Id, Master, Leader, Slaves, Group)
                after Timeout -> 
                    Master ! {error, "No reply from leader"}
            end
    end.

leader(Id, Master, Slaves, Group) ->
    receive
        {mcast, Msg} ->
            bcast(Id, {msg, Msg}, Slaves),
            Master ! Msg,
            leader(Id, Master, Slaves, Group);
        {join, Wrk, Peer} ->
            io:format("slaves: ~w", [Slaves]),
            Slaves2 = lists:append(Slaves, [Peer]),
            Group2 = lists:append(Group, [Wrk]),
            bcast(Id, {view, [self()|Slaves2], Group2}, Slaves2),
            io:format("here, ~w, ~w, ~w ~n", [Id, Slaves2, Group2]),
            Master ! {view, [self()|Slaves2]},
            leader(Id, Master, Slaves2, Group2);
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

slave(Id, Master, Leader, Slaves, Group) ->
    io:format("~w mailbox: ~p~n", [Id, erlang:process_info(self(), messages)]),
    receive 
        {mcast, Msg} ->
            Leader ! {mcast, Msg},
            slave(Id, Master, Leader, Slaves, Group);
        {join, Wrk, Peer} ->
            Leader ! {join, Wrk, Peer},
            slave(Id, Master, Leader, Slaves, Group);
        {msg, Msg} ->
            Master ! {msg, Msg},
            slave(Id, Master, Leader, Slaves, Group);
        {view, [Leader|Slaves2], Group2} ->
            Master ! {view, Group2},
            slave(Id, Master, Leader, Slaves2, Group2);
        {'DOWN', _Ref, process, Leader, _Reason} ->
            io:format("Node ~w noticed leader is down, starting election process ~n", [Id]),
            election(Id, Master, Slaves, Group);
        leader -> 
            io:format("current leader: ~w", [Leader]),
            slave(Id, Master, Leader, Slaves, Group);            
        stop ->
            ok
    end.

election(Id, Master, Slaves, [_|Group]) ->
    Self = self(),
    case Slaves of
        [Self|Rest] ->
            bcast(Id, {view, [Self|Slaves], Group}, Rest),
            Master ! {view, Group},
            leader(Id, Master, Slaves, Group);
        [Leader|Rest] ->
            erlang:monitor(process, Leader),
            slave(Id, Master, Leader, Rest, Group)
    end.

