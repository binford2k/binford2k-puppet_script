# Puppet Script
## Imperative scripts using the Puppet RAL

Puppet's state model is amazing when you're managing configuration. But sometimes
you really just need to make a thing happen. Maybe you need to halt an application,
update its database, then restart it. Maybe you need to take recovery actions when
certain resources fail.

To be clear: in almost every situation, you **should not use this tool**. This is
only for complex processes which are difficult to be automated as a state model.

-----------

Puppet Script allows you to break out of the state model and just list resources
states to manage in an imperative form. There's no dependency management, no
duplicate resources to worry about, no immutable variables. Just write your
script and let Puppet do its magic.

This currently only works with native types, not defined types. And it won't work
with any types that require including some class for setup or anything.


### Writing a script

So what's it look like? It's just a Ruby based DSL. Write Ruby code with constructs
like this to manage resources. Facts are available in the `facts[]` hash.

``` ruby
#! /opt/puppetlabs/bin/puppet script

['one', 'two', 'three'].each do |name|
  resource(:file, "/tmp/#{name}",
    :ensure  => 'file',
    :content => facts['osfamily'],
  )
end

resource(:file, '/tmp/dupe',
  :ensure  => 'file',
  :content => 'hello there',
)

resource(:file, '/tmp/dupe',
  :ensure => 'file',
  :mode   => '0600',
)
```

See the `examples` directory for more complex examples. For example, the
`examples/upgrade.pps` script shows how a database-backed application could be
upgraded, along with the database schema, with health checks and recovery if
anything goes wrong.

If you'd like to use defined resource types, or if you need to enforce some
Puppet code for setup, then you can invoke the `apply()` method and directly
enforce a mini-catalog of Puppet code. It's easiest to use a heredoc, as in
this example:

``` ruby
#! /opt/puppetlabs/bin/puppet script

resource(:file, '/tmp/hello',
  :ensure  => 'file',
  :mode    => '0600',
  :content => 'Hello there',
)

apply <<-EOS
include apache
apache::vhost { $facts['fqdn']:
  port    => '80',
  docroot => '/var/www/vhost',
}
notify { 'hello from puppet code': }
EOS
```


### Running the script

Either make the script executable like any other script, or run it directly
with `puppet script`. See `puppet script --help` for usage information.


```
root@master:~ # puppet script script.pps
File[/this/path/does/not/exist]
  - change from absent to file failed: Could not set 'file' on ensure: No such file or directory @ dir_s_mkdir - /this/path/does/not/exist20170316-7813-308f85.lock
Managed 7 resources with 1 failures.
root@master:~ # chmod +x script.pps
root@master:~ # ./script.pps
File[/this/path/does/not/exist]
  - change from absent to file failed: Could not set 'file' on ensure: No such file or directory @ dir_s_mkdir - /this/path/does/not/exist20170316-7813-308f85.lock
Managed 7 resources with 1 failures.
```


### Installing

This is packaged as a Puppet module. Just drop it in your `modulepath` or put it
in your `Puppetfile`. When I release it on the Forge, you can use `puppet module
install` too.


### Disclaimer

I take no liability for the use of this module. At this point, it's just a proof
of concept.


Contact
-------

binford2k@gmail.com
