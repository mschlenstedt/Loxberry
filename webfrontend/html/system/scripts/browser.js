/* Loxberry webfrontend/html/system/scripts/browser.js 22.01.2018 19:57:37 */
/* Browser detection for IE 10, 11 and Chrome */

$( document ).ready(function() 
{
	/** Target IE 10 with JavaScript and CSS property detection.  Thanks to Tim Pietrusky timpietrusky.com **/
	// IE 10 only CSS properties
	var ie10Styles = [
	     'msTouchAction',
	     'msWrapFlow',
	     'msWrapMargin',
	     'msWrapThrough',
	     'msOverflowStyle',
	     'msScrollChaining',
	     'msScrollLimit',
	     'msScrollLimitXMin',
	     'msScrollLimitYMin',
	     'msScrollLimitXMax',
	     'msScrollLimitYMax',
	     'msScrollRails',
	     'msScrollSnapPointsX',
	     'msScrollSnapPointsY',
	     'msScrollSnapType',
	     'msScrollSnapX',
	     'msScrollSnapY',
	     'msScrollTranslation',
	     'msFlexbox',
	     'msFlex',
	     'msFlexOrder'];
	
	 var ie11Styles = [
	     'msTextCombineHorizontal'];
	 var d = document;
	 var b = d.body;
	 var s = b.style;
	 var ieVersion = null;
	 var property;
	
	 // Test IE10 properties
	 for (var i = 0; i < ie10Styles.length; i++) {
	     property = ie10Styles[i];
	     if (s[property] != undefined) 
	     {
	         ieVersion = "ie10";
	     }
	 }
	 // Test IE11 properties
	 for (var i = 0; i < ie11Styles.length; i++) {
	     property = ie11Styles[i];
	     if (s[property] != undefined) 
	     {
	         ieVersion = "ie11";
	     }
	 }
	
	 if (ieVersion) 
	 {
	     $(b).addClass(ieVersion);
	     $(".footeralignmentIE").css('display','inline-block');
	     $(".footeralignmentIE_l").css('display','inline-block');	
	     $(".footeralignmentIE_r_outer").css('display','inline-block');	
	     $(".footeralignmentIE_l_outer").css('display','inline-block');	
	     $(".footeralignmentIE_r").css('display','inline-block');	
	     $(".footersloganIE_r").css('display','inline-block');	
	     $(".footerlogotextIE").css('display','inline-block');	
	 }
	 else
	 {
 		//Not IE10 or 11.
	     $(".footeralignment").css('display','flex');	
	 }

	var is_chrome = ((navigator.userAgent.toLowerCase().indexOf('chrome') > -1) &&(navigator.vendor.toLowerCase().indexOf("google") > -1));
	if ( is_chrome ) { $(b).addClass("chrome"); }
	});
	
