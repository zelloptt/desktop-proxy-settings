{
    "targets": [{
        "target_name": "<(module_name)",
        "cflags!": [ "-fno-exceptions" ],
        "cflags_cc!": [ "-fno-exceptions" ],
        "sources": [
        ],
      	"conditions":[
      		["OS=='mac'", {
      		    "sources": [
      		        "src/main.cpp",
      		        "src/ProxySettingsEmptyImpl.cpp"
      		    ],
                'configurations': {
                    'Release': {
                       'xcode_settings': {
                          'OTHER_LDFLAGS': [
                          ]
                       }
                    },
                    'Debug': {
                        'xcode_settings': {
                            'VALID_ARCHS': 'arm64 x86_64',
                            'ONLY_ACTIVE_ARCH': 'NO',
                            'OTHER_CFLAGS': [
                                '-arch x86_64',
                                '-arch arm64'
                           ],
                            'OTHER_LDFLAGS': [
                                '-arch x86_64',
                                '-arch arm64',
                                '-framework CoreFoundation'
                           ]
                        }
                    }
                },
                'dependencies': [
                    "./uiohook.gyp:uiohook"
                ],
                "cflags+": ["-fvisibility=hidden"],
                "xcode_settings": {
                "GCC_SYMBOLS_PRIVATE_EXTERN": "YES"
                }
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
        'defines': [ 'NAPI_VERSION=<(napi_build_version)', 'NAPI_DISABLE_CPP_EXCEPTIONS' ],
        'LDFLAGS': [
            '-framework CodeFoundation'
        ]
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
