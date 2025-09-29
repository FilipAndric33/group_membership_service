-module(worker).

-export([start/4, start/5]).
-define(change, 20).
-define(color, {0, 0, 0}).

start(Id, Module, Rnd, Sleep) ->
    spawn(fun() -> init(Id, Module, Rnd, Sleep) end).

init(Id, Module, Rnd, Sleep) ->
    {ok, Cast} = apply(Module, start, [Id]),
    Color = ?color,
    init_cont(Id, Rnd, Cast, Color, Sleep).

start(Id, Module, Rnd, Peer, Sleep) ->
    spawn(fun() -> init(Id, Module, Rnd, Peer, Sleep) end).

init(Id, Module, Rnd, Peer, Sleep) ->
    {ok, Cast} = apply(Module, start, [Id, Peer]),
    {ok, Color} = join(Id, Cast),
    
    Color = ?color,
    init_cont(Id, Rnd, Cast, Color, Sleep).

