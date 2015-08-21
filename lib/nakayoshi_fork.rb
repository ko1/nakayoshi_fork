require "nakayoshi_fork/version"

module NakayoshiFork
  def fork(nakayoshi: true, cow_friendly: true, &b)
    if nakayoshi && cow_friendly
      h = {}
      3.times{ # maximum 3 times
        GC.stat(h)
        live_slots = h[:heap_live_slots] || h[:heap_live_slot]
        old_objects = h[:old_objects] || h[:old_object]
        remwb_unprotects = h[:remembered_wb_unprotected_objects] || h[:remembered_shady_object]
        young_objects = live_slots - old_objects - remwb_unprotects
        break if young_objects < live_slots / 10
        GC.start(full_mark: false)
      }
    end

    super(&b)
  end if GC.method(:start).arity != 0
end

class Object
  prepend NakayoshiFork
end
