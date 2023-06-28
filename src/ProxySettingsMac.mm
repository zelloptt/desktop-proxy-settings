#include "ProxySettings.h"
#define TARGET_OS_MAC
#import <Foundation/Foundation.h>
#import <sstream>
#import <iostream>

static const std::string defaultServer("http://default.zellowork.com");

#define USE_DEFAULT_SERVER_URL     0

std::string getUrl(const Napi::CallbackInfo& info)
{
    std::string url;
    if (info.Length() > 0 && info[0].IsString()) {
        url.assign(info[0].As<Napi::String>());
    }
    if (url.empty()) {
#ifndef USE_DEFAULT_SERVER_URL
        return url;
#endif
        url.assign(defaultServer);
    }
    std::transform(url.begin(), url.end(), url.begin(), [](unsigned char c) {return std::tolower(c); });
    if (url.substr(0, 6).compare("https:") == 0) { // do not support https proxies for now
        url.erase(4, 1);
    }
    if (url.substr(0, 5).compare("http:") != 0) {
        url.insert(0, "http://");
    }
    return url;
}

std::string convert(CFStringRef strRef)
{
    std::string str;
    if (NULL == strRef) {
        return str;
    }
    if (size_t length = static_cast<size_t>(CFStringGetLength(strRef))) {
        if (const char* ptr = CFStringGetCStringPtr(strRef, kCFStringEncodingUTF8)) {
            str.assign(ptr, length);
            return str;
        }
        size_t maxLength = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8) + 1;
        if (char* buffer = new char[maxLength + 1]) {
            buffer[0] = buffer[maxLength] = 0;
            CFStringGetCString(strRef, buffer, maxLength, kCFStringEncodingUTF8);
            str.assign(buffer);
            delete[] buffer;
        }
    }
    return str;
}

bool GetBoolFromDictionary(CFDictionaryRef dict, CFStringRef key, bool& value) {
    CFDictionaryRef cf = NULL;
    if (!CFDictionaryGetValueIfPresent(dict, key, reinterpret_cast<const void**>(&cf))) {
        return false;
    }
    int nValue = 0;
    CFNumberGetValue(reinterpret_cast<CFNumberRef>(cf), kCFNumberIntType, &nValue);
    value = nValue != 0;
    return true;
}

bool GetNumberFromDictionary(CFDictionaryRef dict, CFStringRef key, int& value) {
    CFDictionaryRef cf = NULL;
    if (!CFDictionaryGetValueIfPresent(dict, key, reinterpret_cast<const void**>(&cf))) {
        return false;
    }
    CFNumberGetValue(reinterpret_cast<CFNumberRef>(cf), kCFNumberIntType, &value);
    return true;
}

bool GetStringFromDictionary(CFDictionaryRef dict, CFStringRef key, std::string& value) {
    CFDictionaryRef cf = NULL;
    if (!CFDictionaryGetValueIfPresent(dict, key, reinterpret_cast<const void**>(&cf))) {
        return false;
    }
    if (cf != nullptr) {
        const CFTypeID tid = CFGetTypeID(cf);
        if (tid == CFStringGetTypeID()) {
            value = convert(reinterpret_cast<CFStringRef>(cf));
        } else if (tid == CFURLGetTypeID()) {
            value = convert(CFURLGetString(reinterpret_cast<CFURLRef>(cf)));
        } else {
            std::cerr << "Unknown tid " << tid << " while reading " << convert(key) << "\n";
        }
    }
    return true;
}

enum PROXY_PROTO
{
    PP_NONE = 0,
    PP_HTTP,
    PP_HTTPS,
    PP_SOCKS5,
    PP_PAC,
    PP_UNSUPPORTED = 100
};

PROXY_PROTO parseProxyType(CFStringRef type)
{
   if (type == kCFProxyTypeNone) {
        return PP_NONE;
   } else if (type == kCFProxyTypeHTTP) {
        return PP_HTTP;
   } else if (type == kCFProxyTypeAutoConfigurationURL) {
        return PP_PAC;
   } else if (type == kCFProxyTypeHTTPS) {
        return PP_HTTPS;
   } else if (type == kCFProxyTypeSOCKS) {
        return PP_SOCKS5;
   }
   return PP_UNSUPPORTED;
}

PROXY_PROTO readProxyType(CFDictionaryRef dict)
{
    CFDictionaryRef cf = NULL;
    if (!CFDictionaryGetValueIfPresent(dict, kCFProxyTypeKey, reinterpret_cast<const void**>(&cf))) {
        return PP_UNSUPPORTED;
    }
    return parseProxyType(reinterpret_cast<CFStringRef>(cf));
}

bool isProxySupported(PROXY_PROTO proxyType)
{
    return proxyType == PP_HTTP || proxyType == PP_HTTPS || proxyType == PP_PAC;
}

class Proxies
{
    CFDictionaryRef systemProxy;
    CFArrayRef proxies;
public:
    typedef bool (*fnProcess)(CFDictionaryRef proxy);

    Proxies(const std::string& url) : systemProxy(CFNetworkCopySystemProxySettings()), proxies(NULL)
    {
        if (!url.empty()) {
            CFURLRef urlRef = CFURLCreateWithBytes(NULL, reinterpret_cast<const unsigned char*>(url.c_str()), url.length(), kCFStringEncodingUTF8, NULL);
            proxies = CFNetworkCopyProxiesForURL(urlRef, systemProxy);
            CFRelease(urlRef);
        }
    }

    bool empty() const
    {
        return count() == 0;
    }

    size_t count() const
    {
        return proxies ? static_cast<size_t>(CFArrayGetCount(proxies)) : 0;
    }

    CFDictionaryRef at(size_t idx) const
    {
        return proxies ? reinterpret_cast<CFDictionaryRef>(CFArrayGetValueAtIndex(proxies, idx)) : CFDictionaryRef();
    }

    bool getSystemHttpProxy(std::string& host, int& port) const
    {
        if (!systemProxy) {
            return false;
        }
        bool enabled = false;
        port = 0;
        host.clear();
        if (!GetBoolFromDictionary(systemProxy, kCFNetworkProxiesHTTPEnable, enabled)) {
            return false;
        }
        if (enabled) {
            if (!GetStringFromDictionary(systemProxy, kCFNetworkProxiesHTTPProxy, host)) {
                return false;
            }
            if (!GetNumberFromDictionary(systemProxy, kCFNetworkProxiesHTTPPort, port)) {
                return false;
            }
        }
        return enabled;
    }

    bool getSystemHttpsProxy(std::string& host, int& port) const
    {
        if (!systemProxy) {
            return false;
        }
        bool enabled = false;
        port = 0;
        host.clear();
        if (!GetBoolFromDictionary(systemProxy, kCFNetworkProxiesHTTPSEnable, enabled)) {
            return false;
        }
        if (enabled) {
            if (!GetStringFromDictionary(systemProxy, kCFNetworkProxiesHTTPSProxy, host)) {
                return false;
            }
            if (!GetNumberFromDictionary(systemProxy, kCFNetworkProxiesHTTPSPort, port)) {
                return false;
            }
        }
        return enabled;
    }

    bool getSystemPacProxy(std::string& url, std::string& script) const
    {
        if (!systemProxy) {
            return false;
        }
        bool enabled = false;
        if (!GetBoolFromDictionary(systemProxy, kCFNetworkProxiesProxyAutoConfigEnable, enabled)) {
            return false;
        }
        if (enabled) {
            GetStringFromDictionary(systemProxy, kCFNetworkProxiesProxyAutoConfigURLString, url);
            GetStringFromDictionary(systemProxy, kCFNetworkProxiesProxyAutoConfigJavaScript, script);
            if (url.empty() && script.empty()) {
                enabled = false;
            }
        }
        return enabled;
    }

    void for_each(fnProcess fn)
    {
        if (!proxies) {
            return;
        }
        CFIndex proxiesCount = CFArrayGetCount(proxies);
        if (proxiesCount > 0) {
            for (long idx = 0; idx < proxiesCount; ++idx) {
                if (!fnProcess(CFArrayGetValueAtIndex(proxies, idx))) {
                    break;
                }
            }
        }
    }

    ~Proxies()
    {
        if (proxies) {
            CFRelease(proxies);
        }
        if (systemProxy) {
            CFRelease(systemProxy);
        }
    }
};

bool saveProxyToObject(CFDictionaryRef proxy, Napi::Object& object, const Napi::CallbackInfo& info)
{
    Napi::Env env = info.Env();
    PROXY_PROTO proxyProto = readProxyType(proxy);
    if (proxyProto == PP_NONE) {
        object.Set("enabled", Napi::Boolean::New(env, false));
        return true;
    }
    if (!isProxySupported(proxyProto)) {
        return false;
    }
    object.Set("enabled", Napi::Boolean::New(env, true));
    unsigned uProxyProtocol = 0;  // 0 -- http
    if (proxyProto == PP_HTTP || proxyProto == PP_HTTPS) {
        uProxyProtocol = (proxyProto == PP_HTTPS ? 1 : 0);
        std::string host;
        int port;
        if (GetStringFromDictionary(proxy, kCFProxyHostNameKey, host)) {
            object.Set("host", Napi::String::New(env, host.c_str()));
        }
        if (GetNumberFromDictionary(proxy, kCFProxyPortNumberKey, port)) {
            object.Set("port", Napi::Number::New(env, port));
        }
    } else if (proxyProto == PP_PAC) {
        uProxyProtocol = 3;
        std::string pacData;
        if (GetStringFromDictionary(proxy, kCFProxyAutoConfigurationURLKey, pacData)) {
            object.Set("pacUrl", Napi::String::New(env, pacData.c_str()));
        }
    } else {
        return false;
    }
    object.Set("protocol", Napi::Number::New(env, uProxyProtocol));
    std::string sCredentials;
    if (GetStringFromDictionary(proxy, kCFProxyUsernameKey, sCredentials)) {
        object.Set("username", Napi::String::New(env, sCredentials.c_str()));
    }
    if (GetStringFromDictionary(proxy, kCFProxyPasswordKey, sCredentials)) {
        object.Set("password", Napi::String::New(env, sCredentials.c_str()));
    }
    return true;
}

Napi::Object ProxySettings::read(const Napi::CallbackInfo& info)
{
    Napi::Env env = info.Env();
    Proxies proxies(getUrl(info));
    Napi::Object object = Napi::Object::New(env);
    if (!proxies.empty()) {
        size_t idx = 0, count = proxies.count();
        for (; idx < count; ++idx) {
            if (saveProxyToObject(proxies.at(idx), object, info)) {
                return object;
            }
        }
    }
    bool enable = false;
    std::string host, url, script;
    int port = 0;
    unsigned uProxyProtocol = 0;
    if (proxies.getSystemHttpProxy(host, port)) {
        object.Set("port", Napi::Number::New(env, port));
        object.Set("host", Napi::String::New(env, host.c_str()));
        uProxyProtocol = 0;
        enable = true;
    } else if (proxies.getSystemHttpsProxy(host, port)) {
        object.Set("port", Napi::Number::New(env, port));
        object.Set("host", Napi::String::New(env, host.c_str()));
        uProxyProtocol = 1;
        enable = true;
    } else if (proxies.getSystemPacProxy(url, script)) {
        object.Set("pacUrl", Napi::String::New(env, url.c_str()));
        object.Set("pacScript", Napi::String::New(env, script.c_str()));
        uProxyProtocol = 3;
        enable = true;
    }
    object.Set("enabled", Napi::Boolean::New(env, enable));
    object.Set("protocol", Napi::Number::New(env, uProxyProtocol));
    return object;
}

bool dumpProxy(std::stringstream& log, CFDictionaryRef proxy)
{
    std::string sType;
    if (GetStringFromDictionary(proxy, kCFProxyTypeKey, sType)) {
        log << "Proxy type raw: " << sType;
    }
    PROXY_PROTO proxyProto = readProxyType(proxy);
    log << "Proxy type: " << proxyProto;
    std::string host;
    int port = 0;
    if (GetStringFromDictionary(proxy, kCFProxyHostNameKey, host)) {
        std::cerr << ", host:" << host << "\n";
        log << ", host:" << host;
    }
    if (GetNumberFromDictionary(proxy, kCFProxyPortNumberKey, port)) {
        log << ", port:" << port;
    }
    std::string pacData;
    if (GetStringFromDictionary(proxy, kCFProxyAutoConfigurationURLKey, pacData)) {
        log << ", pacUrl:" << pacData;
    }
    std::string sCredentials;
    if (GetStringFromDictionary(proxy, kCFProxyUsernameKey, sCredentials)) {
        log << ", username" << sCredentials;
    }
    if (GetStringFromDictionary(proxy, kCFProxyPasswordKey, sCredentials)) {
        log << ", password" << sCredentials;
    }
    return true;
}

std::string dumpSystemProxies(const Proxies& proxies)
{
    std::string host;
    int port = 0;
    std::stringstream s;
    s << "Sys proxy cfg: ";

    if (proxies.getSystemHttpProxy(host, port)) {
        s << "HTTP enabled: yes;";
        s << "host: " << host;
        s << "; port: " << port;
    } else {
        s << "HTTP enabled: no;";
    }

    if (proxies.getSystemHttpsProxy(host, port)) {
        s << "HTTPS enabled: yes;";
        s << "host: " << host;
        s << "; port: " << port;
    } else {
        s << "HTTPS enabled: no;";
    }

    std::string url, script;
    if (proxies.getSystemPacProxy(url, script)) {
        s << "pac enabled: yes;";
        s << "url: '" << url;
        s << "'; script: '" << script << "'";
    } else {
        s << "pac not enabled";
    }

    return s.str();
}

Napi::String ProxySettings::dump(const Napi::CallbackInfo& info)
{
    Napi::Env env = info.Env();
    std::string url(getUrl(info));
    std::stringstream log;
    log << "Proxy list for '" << url << "': ";
    Proxies proxies(url);
    if (proxies.empty()) {
        log << "[proxy list is empty]";
    } else {
        size_t idx = 0, count = proxies.count();
        for (; idx < count; ++idx) {
            dumpProxy(log, proxies.at(idx));
        }
    }
    log << "\n";
    log << dumpSystemProxies(proxies);
    log << "\n";
    return Napi::String::New(env, log.str().c_str());
}

Napi::Boolean ProxySettings::openSystemSettings(const Napi::CallbackInfo& info)
{
    Napi::Env env = info.Env();
    // this url doesn't work
    // NSString *urlString = @"x-apple.systempreferences:com.apple.preference.network ? Proxies";
    // [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString : urlString]];
    return Napi::Boolean::New(env, false);
}

Napi::Object InitAll(Napi::Env env, Napi::Object exports)
{
    exports.Set("read", Napi::Function::New(env, ProxySettings::read));
    exports.Set("dump", Napi::Function::New(env, ProxySettings::dump));
    exports.Set("openSystemSettings", Napi::Function::New(env, ProxySettings::openSystemSettings));
    return exports;
}
