#include "ProxySettings.h"

#define WIN32_LEAN_AND_MEAN
#include <Windows.h>

class ProxyRegistry
{
    HKEY key;
public:

    ProxyRegistry() : key(NULL) {
        if (ERROR_SUCCESS != ::RegOpenKeyExA(HKEY_CURRENT_USER, "Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings", 0, KEY_READ, &key)) {
            key = NULL;
        }
    }

    ~ProxyRegistry() {
        if (key) {
            ::RegCloseKey(key);
        }
    }

    HKEY get() {
        return key;
    }
    bool get(LPCSTR name, DWORD& value) {
        DWORD dw;
        DWORD sizeBytes = sizeof(DWORD);
        if (ERROR_SUCCESS == ::RegQueryValueExA(key, name, NULL, NULL, reinterpret_cast<LPBYTE>(&dw), &sizeBytes)) {
            value = dw;
            return true;
        }
        return false;
    }

    bool get(LPCSTR name, std::string& value) {
        bool success = false;
        char* readValue = NULL;
        DWORD sizeBytes = 0;
        DWORD dwErr = ::RegQueryValueEx(key, name, NULL, NULL, NULL, &sizeBytes);
        if (ERROR_MORE_DATA == dwErr || ERROR_SUCCESS == dwErr) {
            DWORD sizeString = sizeBytes + 30;
            if (readValue = new char[sizeString]) {
                ZeroMemory(readValue, sizeBytes);
                if (ERROR_SUCCESS == ::RegQueryValueExA(key, name, NULL, NULL, reinterpret_cast<LPBYTE>(readValue), &sizeString)) {
                    value.assign(readValue);
                    success = true;
                }
                delete[] readValue;
            }
        }
        return success;
    }
};

Napi::Boolean ProxySettings::enabled(const Napi::CallbackInfo& info)
{
    Napi::Env env = info.Env();
    ProxyRegistry storage;
    DWORD enabled = 0;
	return Napi::Boolean::New(env, storage.get("ProxyEnable", enabled) && enabled);
}

Napi::String ProxySettings::dump(const Napi::CallbackInfo& info)
{
    DWORD enabled = 0;
    ProxyRegistry storage;
    Napi::Env env = info.Env();
    std::string str;
    if (storage.get("ProxyEnable", enabled) && enabled) {
       str.append("Proxy enabled,");
       std::string server;
       bool x = storage.get("ProxyServer", server);
       str.append("ProxyRead:Ok,");
       std::string::size_type portOffset = server.find_last_of(L':');
        if (portOffset != std::string::npos) {
            str.append("server=").append(server.substr(0, portOffset));
            str.append(",port=").append(server.substr(portOffset + 1));
        } else {
            str.append("server+port=").append(server).append(",delimiter not found!");
        }
    } else {
        str.append("Proxy not enabled");
    }
    return Napi::String::New(env, str);
}

Napi::Object ProxySettings::reload(const Napi::CallbackInfo& info)
{
    DWORD enabled = 0;
    ProxyRegistry storage;
    Napi::Env env = info.Env();
    Napi::Object object = Napi::Object::New(env);
    if (storage.get("ProxyEnable", enabled) && enabled) {
        std::string server;
        if (storage.get("ProxyServer", server)) {
            object.Set("enabled", Napi::Boolean::New(env, true));
            std::string::size_type portOffset = server.find_last_of(L':');
            if (portOffset != std::string::npos) {
                object.Set("server", Napi::String::New(env, server.substr(0, portOffset).c_str()));
                object.Set("port", Napi::Number::New(env, atol(server.substr(portOffset + 1).c_str())));
            } else {
                object.Set("server", Napi::String::New(env, server.c_str()));
            }
        } else {
            object.Set("enabled", Napi::Boolean::New(env, true));
        }
    } else {
        object.Set("enabled",  Napi::Boolean::New(env, false));
    }
    return object;
}

Napi::Boolean ProxySettings::openSystemSettings(const Napi::CallbackInfo& info)
{
    Napi::Env env = info.Env();
    return Napi::Boolean::New(env, false);
}

Napi::Object InitAll(Napi::Env env, Napi::Object exports)
{
	exports.Set(Napi::String::New(env, "enabled"), Napi::Function::New(env, ProxySettings::enabled));
	exports.Set(Napi::String::New(env, "reload"), Napi::Function::New(env, ProxySettings::reload));
	exports.Set(Napi::String::New(env, "dump"), Napi::Function::New(env, ProxySettings::dump));
	exports.Set(Napi::String::New(env, "openSystemSettings"), Napi::Function::New(env, ProxySettings::openSystemSettings));
	return exports;
}
