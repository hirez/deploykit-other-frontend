require 'rubygems'
require 'sinatra'
require 'yaml'
require 'mcollective'
require 'syslog'
require 'slugify'
require 'gmetric'

set :env,  :production
disable :run

require './grubby.rb'

run Sinatra::Application
