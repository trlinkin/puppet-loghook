require 'puppet'
require 'yaml'


class Loghook
  def initialize ( report )

    @host = report.host
    @report = report
    @matches = []

    conf_file = File.join(Puppet['confdir'],"loghook.yaml")

    if File.exists?(conf_file)
      @conf = YAML.load_file(conf_file)

      # find out matches
      find_matches()

      # process any found matches
      process_hooks()

      Puppet.info('Sucessfuly processed report with Loghook')
    else
      Puppet.warning("Could not load #{conf_file} for report processor Loghook")
    end
  end

  def find_matches ()
    if not @conf['nodes']
      #log the fact the config is bullshit
      Puppet.warning('Loghook report processor has an invalid configuration')
      return
    end

    
    @conf['nodes'].each do |node, config|
      # allow us to match hosts based on regex
      if (node[0,1] == '/' && node[-1,1] == '/')

        # extract and test the regex
        node_re = node[1..-2]
        @matches << config if @host =~ /#{node_re}/ 
        Puppet.info("Loghook found match for #{@host}")  
      else

        # boring old matching
        @matches << config if @host == node  
        Puppet.info("Loghook found match for #{@host}")
      end
    end
  end

  def process_hooks ()
    # no matches were found it seems, return
    return if @matches.empty?


    # lets cycle through our found matches
    @matches.each do |match|

      # we are using report statuses to activate our hooks
      if match['status'][@report.status]

        # we directly map our statuses to the puppet report status values
        match['status'][@report.status].each do |action, data|

          # used case to support different actions in the future
          case action
          when "exec"
            [*data].each do |command|

	      next if not command

              # we should check to make sure we can get the path of the command if it is not qualified
              # even if the command is fully qualified, we can run it through this
              command = command.split(' ')
              command[0] = Puppet::Util::which(command[0]) || command[0]
              command = command.join(' ')

              # we allow hostname substitution for hosts that match the regex
              command = command.gsub('%{host}', @host)

              Puppet.info("Loghook executing exec hook for #{@host}")

              begin
                Puppet::Util::execute(command)
              rescue Puppet::ExceptionFailure => e
                Puppet.warning("Loghook could not execute exec hook for #{@host}: " + e.message)
              end

            end  
          #when "example"
          #else # We have no default for now
          end
        end
      end
    end
  end

end


Puppet::Reports.register_report(:loghook) do
  desc "runs actions based on the end status of puppet nodes"

  def process
      # Loghook is its own class
      Loghook.new(self)
  end

end
