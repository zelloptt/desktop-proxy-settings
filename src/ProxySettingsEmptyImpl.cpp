#include "ProxySettings.h"

Napi::Boolean ProxySettings::enabled(const Napi::CallbackInfo& info)
{
    Napi::Env env = info.Env();
	return Napi::Boolean::New(env, false);
}

Napi::Object ProxySettings::reload(const Napi::CallbackInfo& info)
{
    Napi::Env env = info.Env();
    Napi::Object obj = Napi::Object::New(env);
    return obj;
}

Napi::String dump(const Napi::CallbackInfo& info)
{
    Napi::Env env = info.Env();
	return Napi::String::New(env, "");
}

Napi::Boolean ProxySettings::openSystemSettings(const Napi::CallbackInfo& info)
{
    Napi::Env env = info.Env();
    return Napi::Boolean::New(env, false);
}

Napi::Object InitAll(Napi::Env env, Napi::Object exports)
{
	exports.Set("enabled", Napi::Function::New(env, ProxySettings::enabled));
	exports.Set("reload", Napi::Function::New(env, ProxySettings::reload));
	exports.Set("dump", Napi::Function::New(env, ProxySettings::dump));
	exports.Set("openSystemSettings", Napi::Function::New(env, ProxySettings::openSystemSettings));
	return exports;
}
