%% name of module must match file name
-module(mod_confirm_delivery).

-author("Johan Vorster").

%% Every ejabberd module implements the gen_mod behavior
%% The gen_mod behavior requires two functions: start/2 and stop/1
-behaviour(gen_mod).

%% public methods for this module
-export([start/2, stop/1, send_packet/3, receive_packet/4, get_session/5, set_offline_message/5]).

%% included for writing to ejabberd log file
-include("ejabberd.hrl").

-record(session, {sid, usr, us, priority, info}).
-record(offline_msg, {us, timestamp, expire, from, to, packet}).

-record(confirm_delivery, {messageid, timerref}).

start(_Host, _Opt) -> 

        ?INFO_MSG("mod_confirm_delivery loading", []),
        mnesia:create_table(confirm_delivery, 
            [{attributes, record_info(fields, confirm_delivery)}]),
        mnesia:clear_table(confirm_delivery),
        ?INFO_MSG("created timer ref table", []),

        ?INFO_MSG("start user_send_packet hook", []),
        ejabberd_hooks:add(user_send_packet, _Host, ?MODULE, send_packet, 50),   
        ?INFO_MSG("start user_receive_packet hook", []),
        ejabberd_hooks:add(user_receive_packet, _Host, ?MODULE, receive_packet, 50).   

stop(_Host) -> 
        ?INFO_MSG("stopping mod_confirm_delivery", []),
        ejabberd_hooks:delete(user_send_packet, _Host, ?MODULE, send_packet, 50),
        ejabberd_hooks:delete(user_receive_packet, _Host, ?MODULE, receive_packet, 50). 

send_packet(From, To, Packet) ->    
    ?INFO_MSG("send_packet FromJID ~p ToJID ~p Packet ~p~n",[From, To, Packet]),

    Type = xml:get_tag_attr_s("type", Packet),
    ?INFO_MSG("Message Type ~p~n",[Type]),

    Body = xml:get_path_s(Packet, [{elem, "body"}, cdata]), 
    ?INFO_MSG("Message Body ~p~n",[Body]),

    MessageId = xml:get_tag_attr_s("id", Packet),
    ?INFO_MSG("send_packet MessageId ~p~n",[MessageId]), 

    LUser = element(2, To),
    ?INFO_MSG("send_packet LUser ~p~n",[LUser]), 

    LServer = element(3, To), 
    ?INFO_MSG("send_packet LServer ~p~n",[LServer]), 

    Sessions = mnesia:dirty_index_read(session, {LUser, LServer}, #session.us),
    ?INFO_MSG("Session: ~p~n",[Sessions]),

    case Type =:= "chat" andalso Body =/= [] andalso Sessions =/= [] of
        true ->                

        {ok, Ref} = timer:apply_after(10000, mod_confirm_delivery, get_session, [LUser, LServer, From, To, Packet]),

        ?INFO_MSG("Saving To ~p Ref ~p~n",[MessageId, Ref]),

        F = fun() ->
            mnesia:write(#confirm_delivery{messageid=MessageId, timerref=Ref})
        end,

        mnesia:transaction(F);

    _ ->
        ok
    end.   

receive_packet(_JID, From, To, Packet) ->
    ?INFO_MSG("receive_packet JID: ~p From: ~p To: ~p Packet: ~p~n",[_JID, From, To, Packet]), 

    Received = xml:get_subtag(Packet, "received"), 
    ?INFO_MSG("receive_packet Received Tag ~p~n",[Received]),    

    if Received =/= false andalso Received =/= [] ->
        MessageId = xml:get_tag_attr_s("id", Received),
        ?INFO_MSG("receive_packet MessageId ~p~n",[MessageId]);       
    true ->
        MessageId = []
    end, 

    if MessageId =/= [] ->
        Record = mnesia:dirty_read(confirm_delivery, MessageId),
        ?INFO_MSG("receive_packet Record: ~p~n",[Record]);       
    true ->
        Record = []
    end, 

    if Record =/= [] ->
        [R] = Record,
        ?INFO_MSG("receive_packet Record Elements ~p~n",[R]), 

        Ref = element(3, R),

        ?INFO_MSG("receive_packet Cancel Timer ~p~n",[Ref]), 
        timer:cancel(Ref),

        mnesia:dirty_delete(confirm_delivery, MessageId),
        ?INFO_MSG("confirm_delivery clean up",[]);     
    true ->
        ok
    end.


get_session(User, Server, From, To, Packet) ->   
    ?INFO_MSG("get_session User: ~p Server: ~p From: ~p To ~p Packet ~p~n",[User, Server, From, To, Packet]),   

    ejabberd_router:route(From, To, Packet),
    ?INFO_MSG("Resend message",[]),

    set_offline_message(User, Server, From, To, Packet),
    ?INFO_MSG("Set offline message",[]),

    MessageId = xml:get_tag_attr_s("id", Packet), 
    ?INFO_MSG("get_session MessageId ~p~n",[MessageId]),    

    case MessageId =/= [] of
        true ->        

        mnesia:dirty_delete(confirm_delivery, MessageId),
        ?INFO_MSG("confirm_delivery clean up",[]);

     _ ->
        ok
    end.

set_offline_message(User, Server, From, To, Packet) ->
    ?INFO_MSG("set_offline_message User: ~p Server: ~p From: ~p To ~p Packet ~p~n",[User, Server, From, To, Packet]),    

    F = fun() ->
        mnesia:write(#offline_msg{us = {User, Server}, timestamp = now(), expire = "never", from = From, to = To, packet = Packet})
    end,

    mnesia:transaction(F).   