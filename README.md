ejabberd_confirm_delivery
=========================

Module to sets a message offline if receiver does not respond in 10 seconds

Assuming xep-0184 has been setup client side, this module will wait for a responce from the client. 
If no responce is received in 10 seconds, the module will resend the message (this might be overkill) 
and save the message offline.

As long as the client can handle duplicae messages this technique seems to work fine.

This came from a question I posted on stackoverflow:
http://stackoverflow.com/questions/17424254/ejabberd-online-status-when-user-loses-connection/22606829#22606829

--------------------------------------------------------------------

I have ejabberd setup to be the xmpp server between mobile apps, ie. custom iPhone and Android app.

But I've seemingly run into a limitation of the way ejabberd handles online status's.

Scenario:

User A is messaging User B via their mobiles.
User B loses all connectivity, so client can't disconnect from server.
ejabberd still lists User B as online.
Since ejabberd assumes User B is still online, any message from User A gets passed on to the dead connection.
So user B won't get the message, nor does it get saved as an offline message, as ejabberd assumes the user is online.
Message lost.
Until ejabberd realises that the connection is stale, it treats it as an online user.
And throw in data connection changes (wifi to 3G to 4G to...) and you'll find this happening quite a lot.

mod_ping:

I tried to implement mod_ping on a 10 second interval.
http://www.process-one.net/docs/ejabberd/guide_en.html#htoc51
But as the documentation states, the ping will wait 32 seconds for a response before disconnecting the user. 
This means there will be a 42 second window where the user can lose their messages.

Ideal Solution:

Even if the ping wait time could be reduce, it's still not a perfect solution. 
Is there a way that ejabberd can wait for a 200 response from the client before discarding the message? If no response then save it offline. 
Is it possible to write a hook to solve this problem? 
Or is there a simple setting I've missed somewhere?

FYI: I am not using BOSH.
