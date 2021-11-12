#include "ProxySettings.h"
#define TARGET_OS_MAC
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import <AppKit/AppKit.h>
#include <sstream>

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

enum PROXY_PROTO
{
    PP_NONE = 0,
    PP_HTTP,
    PP_HTTPS,
    PP_SOCKS5,
    PP_PAC,
    PP_UNSUPPORTED = 100
};

std::string convert(CFStringRef strRef)
{
    std::string str;
    if (NULL == strRef) {
        return str;
    }
    if (size_t length = static_cast<size_t>(CFStringGetLength(strRef))) {
        length =  length * 2 + 1;
        if (const char* ptr = CFStringGetCStringPtr(strRef, kCFStringEncodingUTF8)) {
            str.assign(ptr);
        } else if (char* buffer = new char[length]) {
            buffer[0] = buffer[length - 1] = 0;
            CFStringGetCString(strRef, buffer, length, kCFStringEncodingUTF8);
            str.assign(buffer);
            delete[] buffer;
        }
    }
    return str;
}

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

bool isDirect(CFDictionaryRef proxy)
{
    return PP_NONE == parseProxyType(reinterpret_cast<CFStringRef>(CFDictionaryGetValue(proxy, kCFProxyTypeKey)));
}

bool isProxySupported(CFDictionaryRef proxy)
{
    return PP_HTTP == parseProxyType(reinterpret_cast<CFStringRef>(CFDictionaryGetValue(proxy, kCFProxyTypeKey)));
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

    bool getSystemHttpProxy(std::string& host, long& port) const
    {
        if (!systemProxy) {
            return false;
        }
        long enabled = 0;
        port = 0;
        host.clear();
        CFNumberGetValue(reinterpret_cast<CFNumberRef>(CFDictionaryGetValue(systemProxy, kCFNetworkProxiesHTTPEnable)), kCFNumberSInt32Type, &enabled);
        if (enabled) {
            host.assign(convert(reinterpret_cast<CFStringRef>(CFDictionaryGetValue(systemProxy, kCFNetworkProxiesHTTPProxy))));
            CFNumberGetValue(reinterpret_cast<CFNumberRef>(CFDictionaryGetValue(systemProxy, kCFNetworkProxiesHTTPPort)), kCFNumberSInt32Type, &port);
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
    if (isDirect(proxy)) {
        object.Set("enabled", Napi::Boolean::New(env, false));
        return true;
    }
    if (!isProxySupported(proxy)) {
        return false;
    }
    long port = 0;
    CFNumberGetValue(reinterpret_cast<CFNumberRef>(CFDictionaryGetValue(proxy, kCFProxyPortNumberKey)), kCFNumberSInt32Type, &port);
    std::string server = convert(reinterpret_cast<CFStringRef>(CFDictionaryGetValue(proxy, kCFProxyHostNameKey)));
    if (!server.empty() && port > 0) {
        object.Set("enabled", Napi::Boolean::New(env, true));
        object.Set("port", Napi::Number::New(env, port));
        object.Set("server", Napi::String::New(env, server.c_str()));
        std::string username = convert(reinterpret_cast<CFStringRef>(CFDictionaryGetValue(proxy, kCFProxyUsernameKey)));
        std::string password = convert(reinterpret_cast<CFStringRef>(CFDictionaryGetValue(proxy, kCFProxyPasswordKey)));
        if (!username.empty() && !password.empty()) {
            object.Set("username", Napi::String::New(env, username.c_str()));
            object.Set("password", Napi::String::New(env, password.c_str()));
        }
        return true;
    }
    return false;
}

Napi::Boolean ProxySettings::enabled(const Napi::CallbackInfo& info)
{
	Napi::Env env = info.Env();
    Proxies proxies(getUrl(info));
    if (!proxies.empty()) {
        size_t idx = 0, count = proxies.count();
        for (; idx < count; ++idx) {
            CFDictionaryRef proxy = proxies.at(idx);
            if (isDirect(proxy)) {
                return Napi::Boolean::New(env, false);
            } else if (isProxySupported(proxy)) {
                return Napi::Boolean::New(env, true);
            }
        }
    } else {
        std::string host;
        long port = 0;
        return Napi::Boolean::New(env, proxies.getSystemHttpProxy(host, port));
    }
    return Napi::Boolean::New(env, false);
}

Napi::Object ProxySettings::reload(const Napi::CallbackInfo& info)
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
    } else {
        std::string host;
        long port = 0;
        if (proxies.getSystemHttpProxy(host, port)) {
            object.Set("enabled", Napi::Boolean::New(env, true));
            object.Set("port", Napi::Number::New(env, port));
            object.Set("server", Napi::String::New(env, host.c_str()));
        }
    }

    object.Set("enabled", Napi::Boolean::New(env, false));
    return object;
}

bool dumpProxy(std::stringstream& log, CFDictionaryRef proxy)
{
    log << "Proxy type: " << convert(reinterpret_cast<CFStringRef>(CFDictionaryGetValue(proxy, kCFProxyTypeKey)));
    log << ", host:" << convert(reinterpret_cast<CFStringRef>(CFDictionaryGetValue(proxy, kCFProxyHostNameKey)));
    long port = 0;
    CFNumberGetValue(reinterpret_cast<CFNumberRef>(CFDictionaryGetValue(proxy, kCFProxyPortNumberKey)), kCFNumberSInt32Type, &port);
    log << ", port: " << port;
    log << ", username: " << convert(reinterpret_cast<CFStringRef>(CFDictionaryGetValue(proxy, kCFProxyUsernameKey)));
    log << ", password: " << convert(reinterpret_cast<CFStringRef>(CFDictionaryGetValue(proxy, kCFProxyPasswordKey)));
    return true;
}

std::string dumpSystemHttpProxy(const Proxies& proxies)
{
    std::string host;
    long port = 0;
    std::stringstream s;
    s << "Sys proxy cfg: ";
    if (proxies.getSystemHttpProxy(host, port)) {
        s << "HTTPEnable: yes;";
        s << "host: " << host;
        s << "; port: " << port;
    } else {
        s << "HTTPEnable: no;";
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
    log << dumpSystemHttpProxy(proxies);
	return Napi::String::New(env, log.str());
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
	exports.Set("enabled", Napi::Function::New(env, ProxySettings::enabled));
	exports.Set("reload", Napi::Function::New(env, ProxySettings::reload));
	exports.Set("dump", Napi::Function::New(env, ProxySettings::dump));
	exports.Set("openSystemSettings", Napi::Function::New(env, ProxySettings::openSystemSettings));
	return exports;
}
