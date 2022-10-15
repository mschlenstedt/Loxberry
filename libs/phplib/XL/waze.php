<?php

/*
# Copyright 2016-2020 Christian Fenzl for LoxBerry-XL Extended Logic
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# The used Waze API is not official and may be closed by Waze/Google at any time without notice.

*/

$LBWAZEVERSION = "2.2.0.1";

class waze {

	private $fromX, $fromY;
	private $toX, $toY;
	private $data, $routes;
	public $routeinfo;
	
	// Init suncalc
	public function __construct() 
	{
		// Nothing to do here
	}

	public function from( $ypos, $xpos ) {
		$this->fromX = $xpos;
		$this->fromY = $ypos;

	}
	
	public function to( $ypos, $xpos ) {
		$this->toX = $xpos;
		$this->toY = $ypos;
	}

	public function paths( $number_of_paths ) {
		if(empty( $number_of_paths ) || $number_of_paths < 1 || $number_of_paths > 3 ) {
			$this->numberOfPaths = 1;
		} else {
			$this->numberOfPaths = $number_of_paths;
		}
	}

	public function calc() {
		
		$baseurl ="https://www.waze.com/row-RoutingManager/routingRequest?";
		$params = array();
		
		$errors = 0;
				
		if( empty($this->fromX) || empty($this->fromY) ) {
			error_log("Waze: FROM not defined properly");
			$errors++;
		}
		if( empty($this->toX) || empty($this->toY) ) {
			error_log("Waze: TO not defined properly");
			$errors++;
		}
		
		if ( empty($this->numberOfPaths) ) {
			$this->numberOfPaths = 1;
		}
		
		if( $errors > 0 ) {
			error_log( "Please correct $errors to calculate");
			exit(1);
		}
		
		array_push( $params, "from=x%3A".$this->fromX."%20y%3A".$this->fromY."+bd%3Atrue" );
		array_push( $params, "to=x%3A".$this->toX."%20y%3A".$this->toY."+bd%3Atrue" );
		array_push( $params, "at=0" );
		array_push( $params, "returnJSON=true" );
		array_push( $params, "returnGeometries=false" );
		array_push( $params, "returnInstructions=false" );
		array_push( $params, "timeout=60000" );
		array_push( $params, "nPaths=".$this->numberOfPaths );
		array_push( $params, "subscription=*" );
		
		array_push( $params, "options=AVOID_TRAILS%3At,AVOID_TOLL_ROADS%3Af" );
	
		// https://www.waze.com/RoutingManager/routingRequest?from=x%3A-73.96537017822266+y%3A40.77473068237305&to=x%3A-73.99018859863281+y%3A40.751678466796875&at=30&returnJSON=true&returnGeometries=true&returnInstructions=false&timeout=60000&nPaths=3&options=AVOID_TRAILS%3At
		
		// Funktioniert
		// https://www.waze.com/row-RoutingManager/routingRequest?from=x:14.28583%20y:48.30694&to=x:13.7372621%20y:51.0504088&at=0&returnJSON=true&returnGeometries=true&returnInstructions=true&timeout=60000&nPaths=1&clientVersion=4.0.0&options=AVOID_TRAILS%3At%2CALLOW_UTURNS
		
		$params_str = implode( "&", $params );
	
		$opts = array(
			'http'=>array(
				'method'=>"GET",
				'header'=>	"User-Agent: Mozilla/5.0\r\n" .
							"referer: https://www.waze.com/\r\n"
			)
		);
		$context = stream_context_create($opts);
				
		// echo "URL: $baseurl"."$params_str\n";
			
		$jsonresp_str = file_get_contents( $baseurl . $params_str, false, $context );
		
		// $jsonresp_str = file_get_contents("https://www.waze.com/RoutingManager/routingRequest?from=x%3A-73.96537+y%3A40.77473&to=x%3A-73.99018+y%3A40.75167&at=30&returnJSON=true&returnGeometries=true&returnInstructions=false&timeout=60000&nPaths=3&options=AVOID_TRAILS%3At", false, $context);
		file_put_contents( "/opt/loxberry/log/system_tmpfs/route.json", $jsonresp_str);
		$this->data = json_decode( $jsonresp_str );
		
		if( property_exists( $this->data, "alternatives" ) ) {
			// error_log("Multiple paths");
			foreach ( $this->data->alternatives as $i => $routealternative ) {
				$this->routes[$i] = $this->data->alternatives[$i];
			}
		} elseif ( property_exists( $this->data, "response") ) {
			// error_log("Single path");
			$this->routes[0] = $this->data->response;
		} else {
			error_log("Waze: Error or no route found: " . $jsonresp_str);
			return;
		}
	
		return $this->_calc_single_route(0);
		
		// echo "First path name: " . $this->routes[0]->routeName . "\n";
	
	
	}

	
	private function _calc_single_route( $routenumber = 0 ) {
		$routedata = new stdClass();
		$route = $this->routes[$routenumber];
		$routedata->routeName = $route->routeName;
		if( in_array( "Best", (array) $route->routeType) ) {
			$routedata->best = true;
		} else {
			$routedata->best = false;
		}
		
		$routedata->distance = 0;
		$routedata->durationRealtime = 0;
		$routedata->durationNoTraffic = 0;
		$routedata->durationDifference = 0;
		$routedata->detourSavingsRealtime = 0;
		$routedata->detourSavingsNoTraffic = 0;
		
		foreach( $route->results as $key => $segment ) {
			$routedata->distance += $segment->length;
			$routedata->durationRealtime += $segment->crossTime;
			$routedata->durationNoTraffic += $segment->crossTimeWithoutRealTime;
			$routedata->durationDifference += $segment->crossTime - $segment->crossTimeWithoutRealTime;
			$routedata->detourSavingsRealtime += $segment->detourSavings;
			$routedata->detourSavingsNoTraffic += $segment->detourSavingsNoRT;
		}	
		
		$routedata->durationRealtimeMinutes = ceil($routedata->durationRealtime/60);
		$routedata->durationNoTrafficMinutes = ceil($routedata->durationNoTraffic/60);
		$routedata->durationDifferenceMinutes = round($routedata->durationDifference/60);
		$routedata->distanceKilometers = ceil($routedata->distance/1000);

		return (array) $routedata;
	}
}
