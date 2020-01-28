# NakayoshiFork

nakayoshi_fork gem solves CoW friendly issues on MRI 2.2 and later.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'nakayoshi_fork'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install nakayoshi_fork

## Usage

You only need to `require "nakayoshi_fork"` to enable the gem.

If you want to disable `nakayoshi_fork`, use `fork(nakayoshi: false)` or `fork(cow_friendly: false)`.

## Mechanism

### Ruby 2.1 GC

MRI 2.1 uses a generational GC algorithm that separate *young* objects and *old* objects:

1. *Young* objects are promoted to *old* objects when they survive 1 GC cycle.
2. After surviving 1 GC cycle, the `old` bit is set for each *young* object so we can tell that the promoted objects are now *old* objects.

MRI 2.1 also uses a bitmap to store the old object bit which means it's CoW friendly.

### Ruby 2.2 GC

MRI Ruby 2.2 uses an algorithm to promote *young* objects after 3 GC cycles instead of 1.

To count GC survivors, all objects have an *age* field (2 bits field to count fron 0 to 3).

Newly created *young* objects are age 0. Promoted *old* objects are age 3.

Unfortunately, the `age` fields are embedded into object headers. This means that when there 
are many young objects premature promotion is a problem because object headers are written 
and marked as a dirty page.

This is why MRI 2.2 has CoW friendly problem on fork.

The `nakayoshi_fork` gem promotes most of young objects before fork by invoking GC some times.

### Result:

The following results are tests using `nakayoshi_fork` on my environment (2GB 64bit CPU Ubuntu machine).

Test script is here:

```ruby
# make 2**(n+1) ary
def make_obj n
  if n > 0
    [make_obj(n-1), make_obj(n-1)]
  else
    []
  end
end

def object_count
  b = GC.stat[:total_allocated_objects] || GC.stat[:total_allocated_object]
  yield
  a = GC.stat[:total_allocated_objects] || GC.stat[:total_allocated_object]
  a - b
end

created = object_count{
  $objs = make_obj(21) # 4M objects -> 4M * 40B = 160MB
}

puts "created #{created} objects, consumed: #{created * 40 / (1024 * 1024)} MB"

def mem_usage
  _, total, used, free = `free -m -o | grep Mem`.split(/\s+/)
  {total_mem: total, used_mem: used, free_mem: free}
end

# make 10 processes
10.times{
  fork{
    puts 'before gc: ' + mem_usage.inspect
    sleep 5
    puts :GC
    GC.start
    sleep 5
    puts 'after gc :' + mem_usage.inspect
    sleep 5
  }
}
10.times{Process.wait}
puts 'after terminate all processes: ' + mem_usage.inspect
```

Without `nakayoshi_fork`:

```
ruby 2.0.0p402 (2014-02-11) [x86_64-linux]
created 4194305 objects, consumed: 160 MB
before gc: {:total_mem=>"2001", :used_mem=>"386", :free_mem=>"1615"}
before gc: {:total_mem=>"2001", :used_mem=>"390", :free_mem=>"1611"}
before gc: {:total_mem=>"2001", :used_mem=>"391", :free_mem=>"1610"}
before gc: {:total_mem=>"2001", :used_mem=>"392", :free_mem=>"1609"}
before gc: {:total_mem=>"2001", :used_mem=>"392", :free_mem=>"1609"}
before gc: {:total_mem=>"2001", :used_mem=>"392", :free_mem=>"1609"}
before gc: {:total_mem=>"2001", :used_mem=>"394", :free_mem=>"1607"}
before gc: {:total_mem=>"2001", :used_mem=>"394", :free_mem=>"1607"}
before gc: {:total_mem=>"2001", :used_mem=>"394", :free_mem=>"1607"}
before gc: {:total_mem=>"2001", :used_mem=>"393", :free_mem=>"1607"}
...
after gc : {:total_mem=>"2001", :used_mem=>"421", :free_mem=>"1580"}
after gc : {:total_mem=>"2001", :used_mem=>"422", :free_mem=>"1579"}
after gc : {:total_mem=>"2001", :used_mem=>"425", :free_mem=>"1576"}
after gc : {:total_mem=>"2001", :used_mem=>"425", :free_mem=>"1576"}
after gc : {:total_mem=>"2001", :used_mem=>"424", :free_mem=>"1576"}
after gc : {:total_mem=>"2001", :used_mem=>"424", :free_mem=>"1577"}
after gc : {:total_mem=>"2001", :used_mem=>"422", :free_mem=>"1579"}
after gc : {:total_mem=>"2001", :used_mem=>"423", :free_mem=>"1578"}
after gc : {:total_mem=>"2001", :used_mem=>"423", :free_mem=>"1578"}
after gc : {:total_mem=>"2001", :used_mem=>"423", :free_mem=>"1578"}
after terminate all processes: {:total_mem=>"2001", :used_mem=>"385", :free_mem=>"1616"}

ruby 2.1.5p312 (2015-03-10 revision 49912) [x86_64-linux]
created 4194305 objects, consumed: 160 MB
before gc: {:total_mem=>"2001", :used_mem=>"308", :free_mem=>"1693"}
before gc: {:total_mem=>"2001", :used_mem=>"309", :free_mem=>"1692"}
before gc: {:total_mem=>"2001", :used_mem=>"313", :free_mem=>"1688"}
before gc: {:total_mem=>"2001", :used_mem=>"312", :free_mem=>"1689"}
before gc: {:total_mem=>"2001", :used_mem=>"313", :free_mem=>"1688"}
before gc: {:total_mem=>"2001", :used_mem=>"313", :free_mem=>"1688"}
before gc: {:total_mem=>"2001", :used_mem=>"313", :free_mem=>"1688"}
before gc: {:total_mem=>"2001", :used_mem=>"315", :free_mem=>"1686"}
before gc: {:total_mem=>"2001", :used_mem=>"314", :free_mem=>"1686"}
before gc: {:total_mem=>"2001", :used_mem=>"314", :free_mem=>"1686"}
...
after gc : {:total_mem=>"2001", :used_mem=>"585", :free_mem=>"1416"}
after gc : {:total_mem=>"2001", :used_mem=>"587", :free_mem=>"1414"}
after gc : {:total_mem=>"2001", :used_mem=>"587", :free_mem=>"1414"}
after gc : {:total_mem=>"2001", :used_mem=>"587", :free_mem=>"1414"}
after gc : {:total_mem=>"2001", :used_mem=>"586", :free_mem=>"1415"}
after gc : {:total_mem=>"2001", :used_mem=>"586", :free_mem=>"1415"}
after gc : {:total_mem=>"2001", :used_mem=>"586", :free_mem=>"1415"}
after gc : {:total_mem=>"2001", :used_mem=>"586", :free_mem=>"1415"}
after gc : {:total_mem=>"2001", :used_mem=>"586", :free_mem=>"1415"}
after gc : {:total_mem=>"2001", :used_mem=>"586", :free_mem=>"1415"}
after terminate all processes: {:total_mem=>"2001", :used_mem=>"307", :free_mem=>"1694"}

ruby 2.2.3p134 (2015-06-15 revision 50899) [x86_64-linux]
created 4194304 objects, consumed: 160 MB
before gc: {:total_mem=>"2001", :used_mem=>"319", :free_mem=>"1682"}
before gc: {:total_mem=>"2001", :used_mem=>"321", :free_mem=>"1680"}
before gc: {:total_mem=>"2001", :used_mem=>"325", :free_mem=>"1675"}
before gc: {:total_mem=>"2001", :used_mem=>"335", :free_mem=>"1666"}
before gc: {:total_mem=>"2001", :used_mem=>"330", :free_mem=>"1671"}
before gc: {:total_mem=>"2001", :used_mem=>"351", :free_mem=>"1650"}
before gc: {:total_mem=>"2001", :used_mem=>"351", :free_mem=>"1650"}
before gc: {:total_mem=>"2001", :used_mem=>"353", :free_mem=>"1648"}
before gc: {:total_mem=>"2001", :used_mem=>"354", :free_mem=>"1647"}
before gc: {:total_mem=>"2001", :used_mem=>"354", :free_mem=>"1647"}
...
after gc : {:total_mem=>"2001", :used_mem=>"1300", :free_mem=>"701"}
after gc : {:total_mem=>"2001", :used_mem=>"1300", :free_mem=>"701"}
after gc : {:total_mem=>"2001", :used_mem=>"1300", :free_mem=>"701"}
after gc : {:total_mem=>"2001", :used_mem=>"1302", :free_mem=>"699"}
after gc : {:total_mem=>"2001", :used_mem=>"1301", :free_mem=>"700"}
after gc : {:total_mem=>"2001", :used_mem=>"1302", :free_mem=>"699"}
after gc : {:total_mem=>"2001", :used_mem=>"1301", :free_mem=>"699"}
after gc : {:total_mem=>"2001", :used_mem=>"1301", :free_mem=>"699"}
after gc : {:total_mem=>"2001", :used_mem=>"1301", :free_mem=>"700"}
after gc : {:total_mem=>"2001", :used_mem=>"1300", :free_mem=>"700"}
after terminate all processes: {:total_mem=>"2001", :used_mem=>"307", :free_mem=>"1693"}

ruby 2.3.0dev (2015-08-16 trunk 51564) [x86_64-linux]
created 4194304 objects, consumed: 160 MB
before gc: {:total_mem=>"2001", :used_mem=>"310", :free_mem=>"1691"}
before gc: {:total_mem=>"2001", :used_mem=>"310", :free_mem=>"1691"}
before gc: {:total_mem=>"2001", :used_mem=>"310", :free_mem=>"1691"}
before gc: {:total_mem=>"2001", :used_mem=>"312", :free_mem=>"1689"}
before gc: {:total_mem=>"2001", :used_mem=>"311", :free_mem=>"1690"}
before gc: {:total_mem=>"2001", :used_mem=>"314", :free_mem=>"1687"}
before gc: {:total_mem=>"2001", :used_mem=>"315", :free_mem=>"1686"}
before gc: {:total_mem=>"2001", :used_mem=>"314", :free_mem=>"1687"}
before gc: {:total_mem=>"2001", :used_mem=>"316", :free_mem=>"1685"}
before gc: {:total_mem=>"2001", :used_mem=>"316", :free_mem=>"1685"}
...
after gc : {:total_mem=>"2001", :used_mem=>"1268", :free_mem=>"732"}
after gc : {:total_mem=>"2001", :used_mem=>"1269", :free_mem=>"732"}
after gc : {:total_mem=>"2001", :used_mem=>"1269", :free_mem=>"732"}
after gc : {:total_mem=>"2001", :used_mem=>"1269", :free_mem=>"732"}
after gc : {:total_mem=>"2001", :used_mem=>"1270", :free_mem=>"731"}
after gc : {:total_mem=>"2001", :used_mem=>"1270", :free_mem=>"731"}
after gc : {:total_mem=>"2001", :used_mem=>"1270", :free_mem=>"731"}
after gc : {:total_mem=>"2001", :used_mem=>"1270", :free_mem=>"731"}
after gc : {:total_mem=>"2001", :used_mem=>"1269", :free_mem=>"731"}
after gc : {:total_mem=>"2001", :used_mem=>"1269", :free_mem=>"732"}
after terminate all processes: {:total_mem=>"2001", :used_mem=>"308", :free_mem=>"1693"}
```

You can see Ruby 2.2 and Ruby 2.3 consume memory after fork+GC.

Using `nakayoshi_fork`:

```
ruby 2.0.0p402 (2014-02-11) [x86_64-linux]
created 4194305 objects, consumed: 160 MB
before gc: {:total_mem=>"2001", :used_mem=>"391", :free_mem=>"1610"}
before gc: {:total_mem=>"2001", :used_mem=>"394", :free_mem=>"1607"}
before gc: {:total_mem=>"2001", :used_mem=>"394", :free_mem=>"1607"}
before gc: {:total_mem=>"2001", :used_mem=>"395", :free_mem=>"1606"}
before gc: {:total_mem=>"2001", :used_mem=>"397", :free_mem=>"1604"}
before gc: {:total_mem=>"2001", :used_mem=>"396", :free_mem=>"1605"}
before gc: {:total_mem=>"2001", :used_mem=>"397", :free_mem=>"1604"}
before gc: {:total_mem=>"2001", :used_mem=>"396", :free_mem=>"1604"}
before gc: {:total_mem=>"2001", :used_mem=>"397", :free_mem=>"1604"}
before gc: {:total_mem=>"2001", :used_mem=>"396", :free_mem=>"1605"}
...
after gc : {:total_mem=>"2001", :used_mem=>"427", :free_mem=>"1574"}
after gc : {:total_mem=>"2001", :used_mem=>"426", :free_mem=>"1575"}
after gc : {:total_mem=>"2001", :used_mem=>"426", :free_mem=>"1575"}
after gc : {:total_mem=>"2001", :used_mem=>"425", :free_mem=>"1575"}
after gc : {:total_mem=>"2001", :used_mem=>"425", :free_mem=>"1575"}
after gc : {:total_mem=>"2001", :used_mem=>"426", :free_mem=>"1575"}
after gc : {:total_mem=>"2001", :used_mem=>"425", :free_mem=>"1575"}
after gc : {:total_mem=>"2001", :used_mem=>"426", :free_mem=>"1575"}
after gc : {:total_mem=>"2001", :used_mem=>"426", :free_mem=>"1575"}
after gc : {:total_mem=>"2001", :used_mem=>"426", :free_mem=>"1575"}
after terminate all processes: {:total_mem=>"2001", :used_mem=>"388", :free_mem=>"1613"}

ruby 2.1.5p312 (2015-03-10 revision 49912) [x86_64-linux]
created 4194305 objects, consumed: 160 MB
before gc: {:total_mem=>"2001", :used_mem=>"310", :free_mem=>"1690"}
before gc: {:total_mem=>"2001", :used_mem=>"313", :free_mem=>"1688"}
before gc: {:total_mem=>"2001", :used_mem=>"315", :free_mem=>"1685"}
before gc: {:total_mem=>"2001", :used_mem=>"315", :free_mem=>"1686"}
before gc: {:total_mem=>"2001", :used_mem=>"317", :free_mem=>"1683"}
before gc: {:total_mem=>"2001", :used_mem=>"317", :free_mem=>"1683"}
before gc: {:total_mem=>"2001", :used_mem=>"318", :free_mem=>"1683"}
before gc: {:total_mem=>"2001", :used_mem=>"318", :free_mem=>"1683"}
before gc: {:total_mem=>"2001", :used_mem=>"318", :free_mem=>"1683"}
before gc: {:total_mem=>"2001", :used_mem=>"318", :free_mem=>"1683"}
...
after gc : {:total_mem=>"2001", :used_mem=>"363", :free_mem=>"1638"}
after gc : {:total_mem=>"2001", :used_mem=>"363", :free_mem=>"1638"}
after gc : {:total_mem=>"2001", :used_mem=>"363", :free_mem=>"1638"}
after gc : {:total_mem=>"2001", :used_mem=>"363", :free_mem=>"1638"}
after gc : {:total_mem=>"2001", :used_mem=>"363", :free_mem=>"1638"}
after gc : {:total_mem=>"2001", :used_mem=>"363", :free_mem=>"1638"}
after gc : {:total_mem=>"2001", :used_mem=>"363", :free_mem=>"1638"}
after gc : {:total_mem=>"2001", :used_mem=>"363", :free_mem=>"1637"}
after gc : {:total_mem=>"2001", :used_mem=>"363", :free_mem=>"1638"}
after gc : {:total_mem=>"2001", :used_mem=>"363", :free_mem=>"1638"}
after terminate all processes: {:total_mem=>"2001", :used_mem=>"310", :free_mem=>"1691"}

ruby 2.2.3p134 (2015-06-15 revision 50899) [x86_64-linux]
created 4194304 objects, consumed: 160 MB
before gc: {:total_mem=>"2001", :used_mem=>"311", :free_mem=>"1690"}
before gc: {:total_mem=>"2001", :used_mem=>"311", :free_mem=>"1690"}
before gc: {:total_mem=>"2001", :used_mem=>"314", :free_mem=>"1687"}
before gc: {:total_mem=>"2001", :used_mem=>"315", :free_mem=>"1686"}
before gc: {:total_mem=>"2001", :used_mem=>"315", :free_mem=>"1686"}
before gc: {:total_mem=>"2001", :used_mem=>"317", :free_mem=>"1684"}
before gc: {:total_mem=>"2001", :used_mem=>"317", :free_mem=>"1684"}
before gc: {:total_mem=>"2001", :used_mem=>"318", :free_mem=>"1683"}
before gc: {:total_mem=>"2001", :used_mem=>"318", :free_mem=>"1683"}
before gc: {:total_mem=>"2001", :used_mem=>"318", :free_mem=>"1683"}
...
after gc : {:total_mem=>"2001", :used_mem=>"368", :free_mem=>"1633"}
after gc : {:total_mem=>"2001", :used_mem=>"368", :free_mem=>"1633"}
after gc : {:total_mem=>"2001", :used_mem=>"368", :free_mem=>"1633"}
after gc : {:total_mem=>"2001", :used_mem=>"368", :free_mem=>"1633"}
after gc : {:total_mem=>"2001", :used_mem=>"368", :free_mem=>"1633"}
after gc : {:total_mem=>"2001", :used_mem=>"368", :free_mem=>"1633"}
after gc : {:total_mem=>"2001", :used_mem=>"368", :free_mem=>"1633"}
after gc : {:total_mem=>"2001", :used_mem=>"369", :free_mem=>"1632"}
after gc : {:total_mem=>"2001", :used_mem=>"369", :free_mem=>"1632"}
after gc : {:total_mem=>"2001", :used_mem=>"369", :free_mem=>"1632"}
after terminate all processes: {:total_mem=>"2001", :used_mem=>"311", :free_mem=>"1690"}

ruby 2.3.0dev (2015-08-16 trunk 51564) [x86_64-linux]
created 4194304 objects, consumed: 160 MB
before gc: {:total_mem=>"2001", :used_mem=>"312", :free_mem=>"1689"}
before gc: {:total_mem=>"2001", :used_mem=>"313", :free_mem=>"1688"}
before gc: {:total_mem=>"2001", :used_mem=>"312", :free_mem=>"1689"}
before gc: {:total_mem=>"2001", :used_mem=>"315", :free_mem=>"1685"}
before gc: {:total_mem=>"2001", :used_mem=>"315", :free_mem=>"1686"}
before gc: {:total_mem=>"2001", :used_mem=>"317", :free_mem=>"1684"}
before gc: {:total_mem=>"2001", :used_mem=>"317", :free_mem=>"1684"}
before gc: {:total_mem=>"2001", :used_mem=>"318", :free_mem=>"1683"}
before gc: {:total_mem=>"2001", :used_mem=>"319", :free_mem=>"1682"}
before gc: {:total_mem=>"2001", :used_mem=>"319", :free_mem=>"1682"}
...
after gc : {:total_mem=>"2001", :used_mem=>"361", :free_mem=>"1640"}
after gc : {:total_mem=>"2001", :used_mem=>"361", :free_mem=>"1640"}
after gc : {:total_mem=>"2001", :used_mem=>"361", :free_mem=>"1640"}
after gc : {:total_mem=>"2001", :used_mem=>"361", :free_mem=>"1640"}
after gc : {:total_mem=>"2001", :used_mem=>"362", :free_mem=>"1639"}
after gc : {:total_mem=>"2001", :used_mem=>"362", :free_mem=>"1639"}
after gc : {:total_mem=>"2001", :used_mem=>"362", :free_mem=>"1639"}
after gc : {:total_mem=>"2001", :used_mem=>"362", :free_mem=>"1639"}
after gc : {:total_mem=>"2001", :used_mem=>"362", :free_mem=>"1639"}
after gc : {:total_mem=>"2001", :used_mem=>"362", :free_mem=>"1639"}
after terminate all processes: {:total_mem=>"2001", :used_mem=>"310", :free_mem=>"1691"}
```

You can see the improvement after GCs on MRI 2.2 and MRI 2.3-dev.

## Contributing

1. Fork it ( https://github.com/ko1/nakayoshi_fork/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
