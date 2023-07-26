#include <napi.h>

namespace ProxySettings
{
	Napi::Object read(const Napi::CallbackInfo& info);
	Napi::String dump(const Napi::CallbackInfo& info);
	Napi::Boolean openSystemSettings(const Napi::CallbackInfo& info);
}

Napi::Object InitAll(Napi::Env env, Napi::Object exports);
