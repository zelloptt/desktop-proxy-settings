#include "ProxySettings.h"

Napi::Object ProxySettings::read(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
	return Napi::Object::New(env);
}

Napi::String ProxySettings::dump(const Napi::CallbackInfo& info)
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
	exports.Set("read", Napi::Function::New(env, ProxySettings::read));
	exports.Set("dump", Napi::Function::New(env, ProxySettings::dump));
	exports.Set("openSystemSettings", Napi::Function::New(env, ProxySettings::openSystemSettings));
	return exports;
}
