
natives = []

File.open("natives-source.h","r") do |f|
  namespace = nil
  f.lines.each do |line|
    line.gsub!("template<typename... Args> ","")
    line.gsub!("const ","")
    m = line.scan(/static ([^ ]+) (\w+)\((.*)\) { ([^\}]*) } \/\/ (.*)/)
    m2 = line.scan(/namespace (\w+)/)
    if m.size > 0
      natives << {namespace: namespace, return_type: m[0][0], native: m[0][1], args: m[0][2], argc: m[0][2].split(",").size, call: m[0][3], comment: m[0][4]}
    elsif m2.size > 0
      namespace = m2[0][0]
    end
  end
end

def c_return(native)
  case native[:return_type]
    when "int", "Any", "Hash", "Vehicle", "Entity", "Cam", "Object", "Ped", "Player", "ScrHandle", "FireId", "Interior", "Itemset", "Blip", "Pickup"
      ["mrb_int retval = invoker::NativeCall<mrb_int>();","return mrb_fixnum_value( retval );"]
    when "float"
      ["mrb_float retval = invoker::NativeCall<float>();","return mrb_float_value( mrb , retval );"]
    when "BOOL"
      ["BOOL retval = invoker::NativeCall<BOOL>();","return mrb_bool_value( retval );"]
    when "char*", "Any*"
      ["mrb_int retval = invoker::NativeCall<mrb_int>();","return mrb_fixnum_value( retval );"]
    when "void"
      ["invoker::NativeCall<Void>();","return mrb_nil_value();"]
    when "Vector3"
      [
        "Vector3 result = invoker::NativeCall<Vector3>();",
        "mrb_value vector3 = mrb_obj_new(mrb, mrb_class_get(mrb, \"Vector3\"), 0, NULL);",
        "mrb_funcall(mrb, vector3, \"__load\", 3, mrb_float_value(mrb,result.x), mrb_float_value(mrb, result.y), mrb_float_value(mrb, result.z));",
        "return vector3;"
      ]
    else
      raise ArgumentError, "unhandled return type #{native[:return_type].inspect}"
  end
end

def mruby_create_native_methods(natives)
  str = ""
  natives.each do |n|
    func_name = "mruby_#{n[:namespace].downcase}_#{n[:native].downcase}"
    argc = n[:args].split(",").size
    argc = argc > 0 ? "MRB_ARGS_REQ(#{argc})" : "MRB_ARGS_NONE()"
    str << "mrb_define_class_method(mrb, module, \"#{n[:native]}\", #{func_name}, #{argc});\n  "
  end
  str
end

f = File.open("mruby_natives.h","w")

f.puts <<-CPP
#include <redhook2.h>
#include "script.hpp"
#include "natives.h"
#include "types.hpp"

void mruby_push_args(mrb_state* mrb, uint64_t native, int expected_argc) {
  mrb_value* args;
  mrb_int argc;
  mrb_get_args(mrb, "*!", &args, &argc);
  if (argc != expected_argc) OUT("wrong number of opcodes for native %llx (expected %i, got %i)", native, expected_argc, argc);
  for (int i = 0; i < argc; i++) {
    //OUT("mruby_native_call i %i mrb_type(args[i]) %i", i, mrb_type(args[i]));
    switch (mrb_type(args[i])) {
    case MRB_TT_FIXNUM:
      //OUT("mruby_native_call i %i INT %i", i, mrb_fixnum(args[i]));
      invoker::NativePush(mrb_fixnum(args[i]));
      break;
    case MRB_TT_FLOAT:
      //OUT("mruby_native_call i %i FLOAT %f", i, mrb_float(args[i]));
      invoker::NativePush((float)mrb_float(args[i]));
      break;
    case MRB_TT_FALSE:
      //OUT("mruby_native_call i %i FLOAT %f", i, mrb_float(args[i]));
      invoker::NativePush(false);
      break;
    case MRB_TT_TRUE:
      //OUT("mruby_native_call i %i FLOAT %f", i, mrb_float(args[i]));
      invoker::NativePush(true);
      break;
    case MRB_TT_STRING:
      // OUT("mruby_native_call i %i STR %i %s", i, (const char*)mrb_string_value_ptr(mrb, args[i]), (const char*)mrb_string_value_ptr(mrb, args[i]));
      invoker::NativePush((const char*)mrb_string_value_ptr(mrb, args[i]));
      break;
    case MRB_TT_OBJECT:
      //OUT("mruby_native_call i %i FLOAT %f", i, mrb_float(args[i]));
      mrb_value ref = mrb_funcall(mrb, args[i], "__buffer", 0);
      invoker::NativePush((const char*)mrb_string_value_ptr(mrb, ref));
      break;
    default:
      OUT("mruby_native_call i %i UNKNOWN", i);
      break;
    }
  }
}

CPP

natives.each{|n| 
  func_name = "mruby_#{n[:namespace].downcase}_#{n[:native].downcase}"
  native_hex = n[:call].scan(/0x(\w+)/).flatten[0]

  ret = c_return(n)
  f.puts <<-CPP
mrb_value #{func_name}(mrb_state* mrb, mrb_value self){
  invoker::NativeInit( 0x#{native_hex} );
  mruby_push_args( mrb , 0x#{native_hex} , #{n[:argc]} );
  #{ret.join("\n  ")}
}

  CPP
}

f.puts <<-CPP

void mruby_init_natives(mrb_state* mrb, struct RClass* module){
  #{mruby_create_native_methods(natives)}
}

CPP

f.close