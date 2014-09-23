require 'rubygems'
require 'sinatra'

set :env,  :production
disable :run

require './grubby.rb'

run Sinatra::Application
