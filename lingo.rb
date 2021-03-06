#! /usr/bin/ruby
# encoding: utf-8

#  LINGO ist ein Indexierungssystem mit Grundformreduktion, Kompositumzerlegung, 
#  Mehrworterkennung und Relationierung.
#
#  Copyright (C) 2005  John Vorhauer
#
#  This program is free software; you can redistribute it and/or modify it under 
#  the terms of the GNU General Public License as published by the Free Software 
#  Foundation;  either version 2 of the License, or  (at your option)  any later
#  version.
#
#  This program is distributed  in the hope  that it will be useful, but WITHOUT
#  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
#  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
#  You should have received a copy of the  GNU General Public License along with 
#  this program; if not, write to the Free Software Foundation, Inc., 
#  51 Franklin St, Fifth Floor, Boston, MA 02110, USA
#
#  For more information visit http://www.lex-lingo.de or contact me at
#  welcomeATlex-lingoDOTde near 50°55'N+6°55'E.
#
#  Lex Lingo rules from here on


#require 'English'
require 'lib/config'
require 'lib/meeting'


class Lingo

private

  @@config = nil

  def initialize(prog=$0, cmdline=$*)

    $stdin.sync = true
    $stdout.sync = true

    #  Konfiguration bereitstellen
    @@config = LingoConfig.new(prog, cmdline)

    #  Meeting einberufen
    @@meeting = Meeting.new
  end


public

  def Lingo.config
    Lingo.new( 'lingo.rb', [] ) if @@config.nil?
    @@config
  end

  def Lingo.call(config = 'lingo-call.cfg')
    lingo = new('lingo.rb', ['-c', config])
    lingo.talk_to_me('')  # just to build the dicts
    lingo
  end

  def Lingo.meeting
    @@meeting
  end

  def Lingo.error(msg)
    abort msg
  end

  def talk
    attendees = @@config['meeting/attendees']
    @@meeting.invite(attendees)

    protocol = 0
    protocol += 1 if (@@config['cmdline/status'] || false)
    protocol += 2 if (@@config['cmdline/perfmon'] || false)

    @@meeting.start(protocol)

    @@meeting.cleanup
  end

  def talk_to_me(str, &block)
    out = StringIO.new

    old_stdout, $stdout = $stdout, out
    old_stdin,  $stdin  = $stdin,  StringIO.new(str)

    Dir.chdir(File.dirname(__FILE__)) { talk }

    $stdout, $stdin = old_stdout, old_stdin

    res = out.string.split("\n")
    block ? res.map(&block) : res.sort.uniq
  end

end

if $0 == __FILE__

  Lingo.new.talk

end
