<?php

namespace LoxBerry;

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

require_once "/opt/loxberry/libs/phplib/loxberry_system.php";
// require_once "/opt/loxberry/libs/phplib/loxberry_web.php";

use Datto\JsonRpc\Evaluator;
use Datto\JsonRpc\Exceptions\ArgumentException;
use Datto\JsonRpc\Exceptions\MethodException;



class JsonRpcApi implements Evaluator
{
    public function evaluate($method, $arguments)
    {
	/*
        if ($method === 'add') {
            return self::add($arguments);
        }
	*/
		
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
		}
		
		// Prevent non-allowed functions
		if( in_array( strtolower($function), PREVENTED_FUNCTIONS ) ) {
			error_log("JsonRPC: $function is a prevented function.");
			$func_exists=false;
		}
		
		if($func_exists) {
			return call_user_func_array($method, $arguments);
		}
		
		throw new MethodException();
		
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
