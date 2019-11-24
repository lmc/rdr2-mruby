

// script hook
#include "script.hpp"
#include "natives.h"
#include "keyboard.hpp"
#include <redhook2.h>
#include <string>



// console
#include <io.h>
#include <string.h>
#include <fcntl.h>
#include <Psapi.h>
#define _CRT_SECURE_NO_WARNINGS 1
#pragma warning(disable : 4996)

#define OUT(...) (fprintf(stdout,__VA_ARGS__),fprintf(stdout,"\n"))
//#define REL(path) ("C:\\Users\\Barry\\Downloads\\RedHook2-Sample-Project-master\\RedHook2-Sample-Project-master\\source\\mruby\\" path)
#define REL(path) (".\\scripts\\rdr2-mruby\\" path)

static bool console_spawned = false;
void createConsole() {
	HWND window_test = GetConsoleWindow();
	int hConHandle;
	long lStdHandle;
	FILE* fp;

	// don't spawn if the console already exists, pipe reopening will cause a crash
	if (window_test) return;
	if (console_spawned) return;

	AllocConsole();
	AttachConsole(GetCurrentProcessId());

	freopen("CON", "w", stdout);
	freopen("CONIN$", "r", stdin);

	// Redirect unbuffered STDOUT to the console
	lStdHandle = (long)GetStdHandle(STD_OUTPUT_HANDLE);
	hConHandle = _open_osfhandle(lStdHandle, _O_TEXT);
	fp = _fdopen(hConHandle, "w");
	*stdout = *fp;

	setvbuf(stdout, NULL, _IONBF, 0);
	setbuf(stdout, NULL);

	console_spawned = true;
};



// mruby
#include <mruby.h>
#include <mruby/irep.h>
#include <mruby/array.h>
#include <mruby/value.h>
#include <mruby/numeric.h>
#include <mruby/string.h>

bool mruby_needs_init = true;
static mrb_state* mrb;
static struct RClass* module_native;
static struct RClass* module_rdr2;

#include "mruby_natives.h"

mrb_value mruby_create_console_window(mrb_state* mrb, mrb_value self) {
	createConsole();
	return mrb_nil_value();
}

mrb_value mruby_reference_to_f(mrb_state* mrb, mrb_value self) {
	mrb_value obj;
	mrb_get_args(mrb, "o", &obj);
	mrb_value ref = mrb_funcall(mrb, obj, "__buffer", 0);
	const char* bytes = mrb_string_value_ptr(mrb, ref);
	return mrb_float_value(mrb, *(float*)bytes);
}

mrb_value mruby_reference_to_i(mrb_state* mrb, mrb_value self) {
	mrb_value obj;
	mrb_get_args(mrb, "o", &obj);
	mrb_value ref = mrb_funcall(mrb, obj, "__buffer", 0);
	const char* bytes = mrb_string_value_ptr(mrb, ref);
	return mrb_fixnum_value(*(mrb_int*)bytes);
}

mrb_value mruby_reference_to_vector3(mrb_state* mrb, mrb_value self) {
	mrb_value obj;
	mrb_get_args(mrb, "o", &obj);
	mrb_value ref = mrb_funcall(mrb, obj, "__buffer", 0);
	const char* bytes = mrb_string_value_ptr(mrb, ref);
	Vector3 result = *(Vector3*)bytes;
	mrb_value vector3 = mrb_obj_new(mrb, mrb_class_get(mrb, "Vector3"), 0, NULL);
	mrb_funcall(mrb, vector3, "__load", 3, mrb_float_value(mrb,result.x), mrb_float_value(mrb, result.y), mrb_float_value(mrb, result.z));
	return vector3;
}



mrb_value mruby_key_just_up(mrb_state* mrb, mrb_value self) {
	mrb_int code;
	mrb_get_args(mrb, "i", &code);
	
	return mrb_bool_value( KeyJustUp( code ) );
}

mrb_value mruby_reload_next_tick(mrb_state* mrb, mrb_value self) {
	mruby_needs_init = true;
	return mrb_nil_value();
}

mrb_value mruby_dir_glob(mrb_state* mrb, mrb_value self) {
	char* filename;
	mrb_int filename_size;
	char* glob;
	mrb_int glob_size;
	mrb_value block;
	mrb_get_args(mrb, "ss&", &filename, &filename_size, &glob, &glob_size, &block);

	char filename_path[2048];
	char filename_glob[2048];
	sprintf(filename_glob, REL("%s\\%s"), filename, glob);

	HANDLE hFind;
	WIN32_FIND_DATAA FindFileData;
	if ((hFind = FindFirstFileA(filename_glob, &FindFileData)) != INVALID_HANDLE_VALUE) {
		do {
			sprintf(filename_path, REL("%s\\%s"), filename, FindFileData.cFileName);
			mrb_yield(mrb, block, mrb_str_new_cstr(mrb, filename_path));
		} while (FindNextFileA(hFind, &FindFileData));
		FindClose(hFind);
	}
	return mrb_nil_value();
}

mrb_value mruby_file_read(mrb_state* mrb, mrb_value self) {
	char* filename;
	mrb_int filename_size;
	mrb_get_args(mrb, "s", &filename, &filename_size);
	FILE* file = fopen(filename, "r");
	char* buffer;
	int length;
	if (file) {
		fseek(file, 0, SEEK_END);
		length = ftell(file);
		fseek(file, 0, SEEK_SET);
		buffer = (char*)malloc(length+1);
		memset(buffer, 0, length);
		if (buffer)
		{
			fread(buffer, 1, length, file);
		}
		fclose(file);
		buffer[length] = 0;
		return mrb_str_new_cstr(mrb, buffer);
	}
	return mrb_nil_value();
}

void mruby_init() {
	OUT("[mruby_init]");

	mrb = mrb_open();
	OUT("[mruby_init] mrb: %i", mrb);

	OUT("[mruby_init] defining modules...");
	module_native = mrb_define_module(mrb, "Native");
	module_rdr2 = mrb_define_module(mrb, "RDR2");

	mrb_define_class_method(mrb, module_rdr2, "create_console_window!", mruby_create_console_window, MRB_ARGS_NONE());
	mrb_define_class_method(mrb, module_rdr2, "reload_next_tick!", mruby_reload_next_tick, MRB_ARGS_NONE());
	mrb_define_class_method(mrb, module_rdr2, "key_just_up", mruby_key_just_up, MRB_ARGS_REQ(1));
	mrb_define_class_method(mrb, module_rdr2, "dir_glob", mruby_dir_glob, MRB_ARGS_REQ(1));
	mrb_define_class_method(mrb, module_rdr2, "file_read", mruby_file_read, MRB_ARGS_REQ(1));
	mrb_define_class_method(mrb, module_rdr2, "reference_to_f", mruby_reference_to_f, MRB_ARGS_REQ(1));
	mrb_define_class_method(mrb, module_rdr2, "reference_to_i", mruby_reference_to_i, MRB_ARGS_REQ(1));
	mrb_define_class_method(mrb, module_rdr2, "reference_to_vector3", mruby_reference_to_vector3, MRB_ARGS_REQ(1));

	OUT("[mruby_init] defining natives...");
	mruby_init_natives(mrb, module_native);

	OUT("[mruby_init] loading boot.rb...");
	FILE* boot_rb = fopen(REL("boot.rb"), "r");
	mrb_load_file(mrb, boot_rb);
	fclose(boot_rb);

	OUT("[mruby_init] running RDR2.boot!...");
	int ai = mrb_gc_arena_save(mrb);
	mrb_funcall(mrb, mrb_obj_value(module_rdr2), "boot!", 0, NULL);
	mrb_gc_arena_restore(mrb, ai);

	OUT("[mruby_init] loading init.rb...");
	FILE* init_rb = fopen(REL("init.rb"), "r");
	mrb_load_file(mrb, init_rb);
	fclose(init_rb);

	OUT("[mruby_init] running RDR2.init!...");
	int ai2 = mrb_gc_arena_save(mrb);
	mrb_funcall(mrb, mrb_obj_value(module_rdr2), "init!", 0, NULL);
	mrb_gc_arena_restore(mrb, ai2);

	OUT("[mruby_init] done.");
}

void mruby_close() {
	OUT("[mruby_close]");
	mrb_close(mrb);
	OUT("[mruby_close] done.");
}



void ScriptMain()
{
	//createConsole();
	//OUT("[ScriptMain] Console created.");

	while (true)
	{
		if (mruby_needs_init) {
			if (mrb) {
				OUT("[ScriptMain] Reloading...");
				mruby_close();
			}
			mruby_init();
			mruby_needs_init = false;
		}

		if (KeyJustUp(VK_F12)) {
			OUT("[ScriptMain] Reloading next tick...");
			mruby_needs_init = true;
		}

		int ai = mrb_gc_arena_save(mrb);
		mrb_funcall(mrb, mrb_obj_value(module_rdr2), "tick!", 0, NULL);
		mrb_gc_arena_restore(mrb, ai);

		scriptWait(0);
	}
}
