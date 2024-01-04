{
    "targets": [{
        "target_name": "<(module_name)",
        "cflags!": [ "-fexceptions" ],
        "cflags_cc!": [ "-fexceptions" ],
        "sources": [
        ],
      	"conditions":[
      		["OS=='mac'", {
      		    "sources": [
	                "src/ProxySettingsMac.mm",
      		        "src/main.cpp"
      		    ],
                'configurations': {
                    'Debug': {
                       'xcode_settings': {
                          'OTHER_LDFLAGS': [
                          ]
                       }
                    },
                    'Release': {
                        'xcode_settings': {
                           'OTHER_LDFLAGS': [
                           ]
                        }
                    }
                },
                "cflags+": ["-fvisibility=hidden"],
                "xcode_settings": {
                    "GCC_SYMBOLS_PRIVATE_EXTERN": "YES",
                    "GCC_ENABLE_CPP_EXCEPTIONS": "YES",
                    "CLANG_CXX_LIBRARY": "libc++",
                    "MACOSX_DEPLOYMENT_TARGET": "10.7",
                },
                "libraries": [
                    '-framework Foundation'
                ]
      		}],
        	["OS=='win'", {
      	  		"sources": [
            	"src/main.cpp",
	            "src/ProxySettings.cpp",
 			]
      		}],
        	["OS=='linux'", {
      	  		"sources": [
            	"src/main.cpp",
	            "src/ProxySettingsEmptyImpl.cpp"
 			]
      		}]
      	],
        'include_dirs': [
            "<!@(node -p \"require('node-addon-api').include\")"
        ],
        'dependencies': [
            "<!(node -p \"require('node-addon-api').gyp\")"
        ],
        'defines': [ 'NAPI_VERSION=<(napi_build_version)', 'NAPI_DISABLE_CPP_EXCEPTIONS' ]
    },
    {
      'target_name': 'action_after_build',
      'type': 'none',
      'dependencies': [ "<(module_name)" ],
      'copies': [
          {
            'files': [ '<(PRODUCT_DIR)/<(module_name).node' ],
            'destination': '<(module_path)'
          }
      ]
    }

]
}
