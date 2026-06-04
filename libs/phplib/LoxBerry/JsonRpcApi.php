<?php

namespace LoxBerry;

require_once "/opt/loxberry/libs/phplib/loxberry_system.php";
require_once "/opt/loxberry/libs/phplib/loxberry_web.php";
require_once "/opt/loxberry/libs/phplib/loxberry_io.php";
require_once "/opt/loxberry/libs/phplib/loxberry_storage.php";

// Version 1.5.0.2

// These functions are prevented by the server for security reasons
CONST PREVENTED_FUNCTIONS = [ 
	"apache_child_terminate", 
	"assert", 
	"create_function", 
	"eval", 
	"exec", 
	"fsockopen", 
	"include", 
	"include_once", 
	"ini_set", 
	"passthru", 
	"pcntl_exec", 
	"phpinfo", 
	"pfsockopen", 
	"popen", 
	"posix_kill", 
	"posix_mkfifo", 
	"posix_setpgid", 
	"posix_setsid", 
	"posix_setuid",
	"preg_replace", 
	"proc_close", 
	"proc_nice", 
	"proc_open", 
	"proc_terminate", 
	"putenv", 
	"require", 
	"require_once", 
	"shell_exec", 
	"system", 
	"use", 
];


use Datto\JsonRpc\Evaluator;
use Datto\JsonRpc\Exceptions\ArgumentException;
use Datto\JsonRpc\Exceptions\MethodException;



class JsonRpcApi implements Evaluator
{
    public function evaluate($method, $arguments)
    {
	
        if ($method === 'getdirs') {
            return self::getdirs($arguments);
        }
	
		
		//echo "Method: $method\n";
		//echo "Arguments: " . join(" ", $arguments) . "\n";
		
		@list ($ns, $function) = explode("::", $method, 2);
		if(empty($function)) {
			$function = $ns;
			$ns = null;
		}
		
		// echo "Namespace: $ns\n";
		// echo "Function : $function\n";
		
		$func_exists=false;
		if(empty($ns) && function_exists($function)) {
			$func_exists=true;
		} elseif (!empty($ns) && method_exists($ns, $function)) {
			$func_exists=true;
		} elseif (empty($ns) && method_exists("LBSystem", $function) ) {
			$ns="LBSystem";
			$func_exists=true;
		} elseif (empty($ns) && method_exists("LBWeb", $function) ) {
			$ns="LBWeb";
			$func_exists=true;
		}
		
		if(!empty($ns)) {
			$method="$ns::$function";
		}
		
		// Prevent non-allowed functions
		if( in_array( strtolower($function), PREVENTED_FUNCTIONS ) ) {
			error_log("JsonRPC: $function is a prevented function.");
			$func_exists=false;
		}
		
		if($func_exists) {
			$callresp = call_user_func_array($method, $arguments);
			if($callresp === false) {
				throw new ApplicationException(); 
			}
			return $callresp;
		
		}
		
		throw new MethodException();
		
	}

	private static function getdirs($arguments)
    {
        @list($pluginname) = $arguments;

        if (empty($pluginname)) {
            throw new ArgumentException("Argument pluginname missing");
        }
		
		$plugin = \LBSystem::plugindata($pluginname);
		if(empty($plugin)) {
			throw new ArgumentException("Plugin $pluginname not found");
		}
		
		$plugindir = $plugin['PLUGINDB_FOLDER'];
		$dirs['lbhomedir'] = LBHOMEDIR;
		
		$dirs['lbpplugindir'] = $plugindir;
		$dirs['lbphtmlauthdir'] = LBHOMEDIR . '/webfrontend/htmlauth/plugins/' . $plugindir;
		$dirs['lbphtmldir'] = LBHOMEDIR . '/webfrontend/html/plugins/' . $plugindir;
		$dirs['lbptemplatedir'] = LBHOMEDIR . '/templates/plugins/' . $plugindir;
		$dirs['lbpdatadir'] = LBHOMEDIR . '/data/plugins/' . $plugindir;
		$dirs['lbplogdir'] = LBHOMEDIR . '/logs/plugins/' . $plugindir;
		$dirs['lbpconfigdir'] = LBHOMEDIR . '/config/plugins/' . $plugindir;
		$dirs['lbpbindir'] = LBHOMEDIR . '/bin/plugins/' . $plugindir;
		
		$dirs['lbshtmlauthdir'] = LBSHTMLAUTHDIR;
		$dirs['lbshtmldir'] = LBSHTMLDIR;
		$dirs['lbstemplatedir'] = LBSTEMPLATEDIR;
		$dirs['lbsdatadir'] = LBSDATADIR;
		$dirs['lbslogdir'] = LBSLOGDIR;
		$dirs['lbstmpfslogdir'] = LBSTMPFSLOGDIR;
		$dirs['lbsconfigdir'] = LBSCONFIGDIR;
		$dirs['lbsbindir'] = LBSBINDIR;
		$dirs['lbssbindir'] = LBSSBINDIR;
		
		return $dirs;
		
		
        
    }

    // private static function add($arguments)
    // {
        // @list($a, $b) = $arguments;

        // if (!is_int($a) || !is_int($b)) {
            // throw new ArgumentException();
        // }

        // return "10";
    // }
}
