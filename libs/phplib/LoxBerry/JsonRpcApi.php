<?php

namespace LoxBerry;

// Version 1.5.0.1


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
		
		echo "Method: $method\n";
		echo "Arguments: " . join(" ", $arguments) . "\n";
		list ($ns, $function) = explode("::", $method, 2);
		if(empty($function)) {
			$function = $ns;
			$ns = null;
		}
		
		echo "Namespace: $ns\n";
		echo "Function : $function\n";
		
		
		$func_exists=false;
		if(empty($ns) && function_exists($function)) {
			$func_exists=true;
		} elseif (!empty($ns) && method_exists($ns, $function)) {
			$func_exists=true;
		}
		
		if($func_exists) {
			// return call_user_func($method, $arguments);
			// return $method($arguments);
			// return $method("squeezelite");
			return call_user_func_array($method, $arguments);
		}
		
		throw new MethodException();
		
	}

    private static function add($arguments)
    {
        @list($a, $b) = $arguments;

        if (!is_int($a) || !is_int($b)) {
            throw new ArgumentException();
        }

        return "10";
    }
}
