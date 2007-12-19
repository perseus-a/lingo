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

require 'lingo/config'
require 'lingo/meeting'

class Lingo

  @@config = nil

  class << self

    def config
      new('lingo.rb', []) if @@config.nil?
      @@config
    end

    def meeting
      @@meeting
    end

    def error(txt)
      puts
      puts txt
      puts

      exit
    end

  end

  def initialize(prog = $0, cmdline = $*)
    STDIN.sync  = true
    STDOUT.sync = true

    # Konfiguration bereitstellen
    @@config = Config.new(prog, cmdline)

    # Meeting einberufen
    @@meeting = Meeting.new
  end

  def talk
    attendees = @@config['meeting/attendees']
    @@meeting.invite(attendees)

    protocol = 0
    protocol += 1 if @@config['cmdline/status']
    protocol += 2 if @@config['cmdline/perfmon']

    @@meeting.start(protocol)
  end

end
