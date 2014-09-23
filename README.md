deploykit-other-frontend
========================

Grubby. Son of Grabby.

What?
=====

Exactly enough dodgy Ruby/Sinatra to demonstrate the possibility of one-click deploys via the 
magic of MCollective. Naturally it's in production.

Why?
====

So anyone with access to the thing can deploy a site. Quickly. 

I mean, if you like big, ceremonial 
deploys that require the entire Ops team to be standing to attention by their desks at 8AM and only 
finish when the last developer has been strangled with the entrails of the last project manager, then 
by all means sling your hook.

Installation.
=============

It's a Sinatra project. You will need:

Ruby > 1.8.
Bundler.
Nginx.
A working MCollective instance.
The 'gitagent' package.

'nginx-vhost' contains, remarkably enough, a Nginx vhost.
'initscript' contains, well, take a guess.

The rest of the files are as self-contained as a Ruby webswerver ever gets.

'bundle install --binstubs --path vendor/bundle' will haul down a pile of Ruby gubbins (Sinatra, STOMP).

At which point 'bin/unicorn -c ./unicorn.conf' will do something. If you were sensible and ran it as $punter, then 
it will moan about not being able to write to /var/run/unicorn - you can either change that to something you prefer, 
remembering to change the corresponding line in unicorn.conf also, create that dir and chown it to whatever user you plan
to run the job as (www-data in our case), or mangle the initscript to brickhammer it in on startup.

If you hate Unicorn and/or Nginx, then you can use whatever Ruby app-serving environment you like best. Patches welcome!

sites.yaml contains the definitions of how MCollective should find the target boxes. There are examples.

It's more or less essential that your MCollective rig is working already. As is having already installed 'gitagent' and being 
able to drive that from the command-line.

Things to do.
=============

Either make grubby able to signal your load-balancers so each node can be dropped out in turn, or have the web-nodes do it 
themselves. I favour the latter path.

Avoid making it any more complex.

