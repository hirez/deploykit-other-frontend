#!/usr/bin/env ruby

require 'rubygems'
#require 'bundler/setup'

require 'sinatra'
require 'yaml'
require 'mcollective'
require 'syslog'

include MCollective::RPC

enable :sessions
set :session_secret, 'Felle helle felle helle felle hola. Chris Waddle.'

$deploylist = YAML.load_file("sites.yaml")

class Wrapper
  include MCollective::RPC

  def initialize(agent)
    @client = rpcclient(agent)
  end

  def method_missing(method, *args)
    @client.send(method, args[0] || {})
  end
end

def tag_select(rsite)
  @site = rsite

  @payload = $deploylist[@site]['payload']
  @filter = $deploylist[@site]['filter']
  @repo = $deploylist[@site]['repo']
  @ntags = $deploylist[@site]['tags']
  @repo_type = $deploylist[@site]['repo_type']

  case @repo_type
  when "git"
    @tags = Hash.new(0)
    @branches = Hash.new(0)
    gstate = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
  
    gitagent = rpcclient("gitagent")
  
    if ['class_filter', 'fact_filter', 'identity_filter', 'compound_filter'].include? @filter
      gitagent.send(@filter.to_sym,@payload)
    else
      "Shonky filtering malarkey."
    end

    @nodelist = gitagent.discover
    @nodec = @nodelist.count

    @nodelist.each do |node|
      gitagent.custom_request("git_tag",{:repo => @repo,:count => @ntags}, "#{node}", {"identity" => "#{node}"}) do |out|
        begin
          blep = out[:body]
          flem = out[:data]
          machine = out[:senderid]
        rescue Exception => e
          puts "The agent returned an error: #{e}"
        end
        @taglist = blep[:data][:tout].split(/\n/)
        @branchlist = blep[:data][:bout].split(/\n/)
    
        gstate[machine]['tags'] = @taglist
        gstate[machine]['branches'] = @branchlist
      end
    end

    gstate.each do |mnode, git|
      git['tags'].each do |tag|
        @tags[tag] = @tags[tag] +1
      end
      git['branches'].each do |branch|
        @branches[branch] = @branches[branch] + 1
      end
    end

    if @nodec
      session[:taglist] = @taglist
      session[:branchlist] = @branchlist
      session[:repo] = @repo
      session[:payload] = @payload
      session[:filter] = @filter
      session[:site] = @site
    end

    @frod = "Repo: #{@repo}\n\n"
    gitagent.git_state(:repo => @repo).each do |out|
      result = out[:data][:tstate]
      result = "Old version of gitagent\n" if out[:statusmsg] =~ /^Unknown action/
      result = "Tagfile not yet extant\n" if out[:statusmsg] =~ /^No such file or directory/
      @frod << "#{out[:sender]} - #{result}"
    end
    erb :deploy

  when "svn"
    svn = Wrapper.new("svn")
    session[:filter] = @filter
    session[:payload] = @payload
    session[:repo] = @repo

    @fred = "#{@filter}: #{@payload}\n"

    if ['class_filter', 'fact_filter', 'identity_filter', 'compound_filter'].include? @filter
      svn.send(@filter.to_sym,@payload)
    else
      "Shonky filtering malarkey."
    end

    svn.info(:repo => @repo, :dest => "dunno").each do |out|
      @fred << "#{out[:sender]}\n"
      
      @fred << "#{out[:data][:stdout]}\n"
  
      ["pre", "post"].each do |type|
        if out[:data]["#{type}_deploy".to_sym] != nil
          @fred << "#{type.capitalize} deploy:"
          @fred << out[:data]["#{type}_deploy".to_sym]
          @fred << "\n"
        end
      end
      @fred << "#{out[:statusmsg]}\n"
    end
    erb :svndeploy
  end
end

def svn_sw
    require 'digest/md5'
    # when I fix the agent to not use a magic variable,
    # this can die in a fire
    @dest = "dunno"

    @filter = session[:filter]
    @payload = session[:payload]
    @repo = session[:repo]
    @svn_url = @repo + "/" + params[:stubbytag]

    session[:reportref] = Digest::MD5.hexdigest("#{@svn_url}sw")
    
    svn = Wrapper.new("svn")

    if ['class_filter', 'fact_filter', 'identity_filter', 'compound_filter'].include? @filter
      svn.send(@filter.to_sym,@payload)
    else
      "Shonky filtering malarkey."
    end

    @fred = "Deploying #{@svn_url}:\n"

    svn.sw(:repo => @repo, :tag => @svn_url, :dest => @dest, :detach => "true").each do |out|
      @fred << "#{out[:sender]}\n"
      @fred << "#{out[:data][:message]}\n"
      @fred << "PID: #{out[:data][:pid]}\n"
      @fred << "#{out[:stdout]}\n#{out[:stderr]}"
    end
    erb :svn_results
end

def svn_report
  @filter = session[:filter]
  @payload = session[:payload]
  @reportref = "#{session[:reportref]}"

  svnreport = Wrapper.new("svnreport") # yes really - not my fault

  if ['class_filter', 'fact_filter', 'identity_filter', 'compound_filter'].include? @filter
    svnreport.send(@filter.to_sym,@payload)
  else
    "Shonky filtering malarkey."
  end

  @report = "Report ref: #{@reportref}\n"
  
  svnreport.report(:ref => @reportref).each do |out|
    @report  << "#{out[:sender]}\n"
    @report  << "#{out[:data][:message]}\n"
    @report  << "stdout: #{out[:data][:stdout]}\n"
    @report  << "stderr: #{out[:data][:stderr]}\n"
    @report  << "pid: #{out[:data][:pid]}\n"
    @report  << "#{out[:statusmsg]}\n"
  end

  erb :svn_report
end

def site_deploy

  @tag = params[:grubbytag].strip
  @site = session[:site] if session[:site]
  @repo = session[:repo] if session[:repo]
  @payload = session[:payload] if session[:payload]
  @filter = session[:filter] if session[:filter]

  @gitagent = rpcclient('gitagent')

  if ['class_filter', 'fact_filter', 'identity_filter', 'compound_filter'].include? @filter
    @gitagent.send(@filter.to_sym,@payload)
  else
    "Shonky filtering malarkey."
  end

  @nodelist = @gitagent.discover

  @fred = "LB-aware deploy\n\n"

  @nodelist.each do |node|
    @fred << "== #{node} ==\n"
    @gitagent.custom_request("git_checkout",{:repo => @repo,:tag => @tag}, "#{node}", {"identity" => "#{node}"}).each do |out|
      @fred << "\n#{out[:sender]} #{out[:data][:detail]}\n\n" if out[:data][:detail]
      @fred << "#{out[:sender]} Pre-deploy script #{out[:data][:trub1]}:\n#{out[:data][:prerr]}\n#{out[:data][:prout]}\nExitcode: #{out[:data][:prstat]}\n\n"
      @fred << "#{out[:sender]} Update site #{out[:data][:lsit]} to tag #{@tag} from repo #{out[:data][:lrep]}:\n#{out[:data][:derr]}\n#{out[:data][:dout]}Exitcode: #{out[:data][:dstat]}\n\n" if out[:data][:prstat] == 0
      @fred << "#{out[:sender]} Post-deploy script #{out[:data][:trub2]}:\n#{out[:data][:poerr]}\n#{out[:data][:poout]}\nExitcode: #{out[:data][:postat]}\n" if out[:data][:dstat] == 0
    end
  end

  erb :results
end

get '/' do
  erb :index
end

get '/site/:restsite' do
  @site = params[:restsite]

  if $deploylist[@site]
    tag_select(@site)
  else
    "Yer wot, pal?"
  end
end

post '/select' do
  @site = params[:grubbysite] if params[:grubbysite]

  if $deploylist[@site]
    tag_select(@site)
  else
    "Oh? Really?"
  end
end

post '/site/deploy' do
  site_deploy
end

post '/deploy' do
  site_deploy
end

post '/svn_sw' do
  svn_sw
end

get '/svn_report' do
  svn_report
end
