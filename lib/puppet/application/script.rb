require 'puppet/application'

class Puppet::Application::Script < Puppet::Application
  option("--debug",      "-d")
  option("--keep-going", "-k")
  option("--verbose",    "-v")

  BUILTINS = [
    'Stage[main]',
    'Class[Settings]',
    'Class[Main]',
    'Schedule[puppet]',
    'Schedule[hourly]',
    'Schedule[daily]',
    'Schedule[weekly]',
    'Schedule[monthly]',
    'Schedule[never]',
    'Filebucket[puppet]',
  ]

  def help
    <<-'HELP'
puppet-script(8) -- It's a script thing, yo.

You probably don't want to use this. It's almost always a better, less fragile,
and more maintainable solution to simply model a complete configuration state
using standard Puppet classification. This serves the few edge cases in which
that's not appropriate.

See the README for more information and an example of a Puppet script.

OPTIONS
-------
Like anything else Puppet, any setting that's valid in the configuration file is
also a valid long argument. For example, 'modulepath' is a valid setting, so you
can specify '--modulepath /path/to/modules' as an argument.  See the docs at
https://docs.puppetlabs.com/puppet/latest/reference/configuration.html for the
full list of acceptable parameters. A commented list of all configuration
options can also be generated by running 'puppet config print --all'.

* --debug:
  Enable full debugging.

* --keep-going:
  Don't stop execution when a resource fails.

* --verbose:
  Print extra information, such as the name of each resource as it's being managed.

* --help:
  Print this help message

    HELP
  end

  def ref(type, name)
    "#{type.capitalize}[#{name}]"
  end

  def key(type, name)
    [type, name].join('/')
  end

  def resource(type, name, params)
    puts "Enforcing #{ref(type, name)}" if options[:verbose]
    key = key(type, name)
    resource = Puppet::Resource.new( type, name, :parameters => params )
    result   = Puppet::Resource.indirection.save(resource, key)

    # jfc
    status = result.last.resource_statuses.first.last

    if status.failed
      event = status.events.first.message
      @errors << event

      raise(Puppet::ResourceError, "Failed enforcing #{ref(type, name)}") unless options[:keep_going]
    end

    puts result.first.inspect if options[:debug]
    @resources << result.first
  end

  def apply(code)
    puts "Running Puppet code block" if options[:verbose]

    begin
      node = Puppet::Node.new('script')
      Puppet[:code] = code
      catalog = Puppet::Parser::Compiler.compile(node).filter { |r| r.virtual? }
      catalog = catalog.to_ral
      catalog.finalize

      prioritizer = Puppet::Graph::SequentialPrioritizer.new
      transaction = Puppet::Transaction.new(catalog,
                                           Puppet::Transaction::Report.new('script'),
                                           prioritizer)

      transaction.evaluate
      transaction.report.finalize_report

    rescue Puppet::ResourceError => e
      @errors << e.message
      raise e unless options[:keep_going]
    end

    catalog.resources.each do |res|
      next if BUILTINS.include? res.ref
      @resources << res
    end
  end

  def main
    @errors    = []
    @resources = []
    filename   = command_line.args.shift

    Puppet::Util::Log.newdestination(:console)
    set_log_level

    raise "Could not find script file #{filename}" unless Puppet::FileSystem.exist?(filename)
    Puppet.warning("Only one script will be executed per run.  Skipping #{command_line.args.join(', ')}") if command_line.args.size > 0

    begin
      facts  = Facter.to_hash
      script = Puppet::FileSystem.read(filename)
      instance_eval(script)
    rescue Puppet::ResourceError, StandardError, SyntaxError => e
      $stderr.puts e.message
    end

    puts "Managed #{@resources.size} resources with #{@errors.size} failures."
    @errors.each { |err| $stderr.puts err }
    exit(@errors.size)
  end
end
