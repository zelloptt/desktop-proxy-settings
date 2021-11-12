#include <napi.h>

namespace ProxySettings
{
	Napi::Boolean enabled(const Napi::CallbackInfo& info);
	Napi::Object reload(const Napi::CallbackInfo& info);
	Napi::String dump(const Napi::CallbackInfo& info);
	Napi::Boolean openSystemSettings(const Napi::CallbackInfo& info);
}

Napi::Object InitAll(Napi::Env env, Napi::Object exports);
