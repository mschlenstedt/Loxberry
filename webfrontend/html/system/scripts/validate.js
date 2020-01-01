/* Loxberry webfrontend/html/system/scripts/validate.js */

function validate_enable ( object )
{
	// Fix for variables with special chars
	object = object.replace( /(\\)/g, "" );
	object_without_escape = object;
	object = object.replace(  /(:|\.|\[|\]|,|=|@)/g, "\\$1" );

	// This function is called from the code to enable validation for this object
	// Create target div for the tooltip - it's named error-msg-<object-id> and inserted after <object-id> (INPUT) which must exists in the HTML page
	$( '<div style="display:none;" id="error-msg-'+object_without_escape.substring(1)+'">'+$(object).attr('data-validation-error-msg')+'</div>' ).insertAfter( $( object ) );
	$(".ui-input-text").css("margin-bottom",0);
    
	// Prevent return key
	$(object).keypress(function(e){ return e.which != 13; });

	// Save original background-color
	originalbackgroundcolor = ( typeof $(object).attr("background-color") != 'undefined') ? $(object).attr("background-color") : "transparent";
	$(object).attr("original-background-color", originalbackgroundcolor );

	// The global variable window.obj_to_validate holds all objects which prevent submitting the form,
	// if the content doesn't match the rule in parameter data-validation-rule of the INPUT
	// Checking here if window.obj_to_validate is set and valid, otherwise create an empty array
	window.obj_to_validate = ( typeof window.obj_to_validate != 'undefined' && window.obj_to_validate instanceof Array ) ? window.obj_to_validate : [];

	// Find the form which is related to the object to validate.
	$( $(object).closest('form') ).submit(function(e)
	{
		// Call function validate_all() and it is NOT true, prevent submitting the form.
		if (!validate_all() && window.validate_override != 1)
		{
			// Prevent submitting the form.
			e.preventDefault();
		}
	});

	// Adding an event handler if someone pastes a value into the INPUT
	$(object).on('paste', function(e)
	{
		if(navigator.userAgent.toLowerCase().indexOf('firefox') > -1)
		{
	     	// Firefox doesn't support this
	     	return;
		}
		else
		{	// In case of pasting values, remove any formatting
			validate_OnPaste_StripFormatting(this, event);
		}
	});

	// Adding an event handler if someone leaves, enters the INPUT or
	// lift the finger from a key into the INPUT
	$(object).on('blur input keyup', function(e)
	{
		validate_chk_value( object,e );
	});
}

function validate_all()
{
	// This function validates all INPUT which were added to the array window.obj_to_validate
	// by calling the validate_chk_object(['<OBJECT>']); from the HTML page
	// The function validate_all() returns true only, if all fields are correct filled.
	// As soon as one field is wrong, false is returned. If the array window.obj_to_validate is
	// empty, true is returned.
	var trueCount       =-1;
	var falseCount      =-1;

	// Put the array window.obj_to_validate in to the local variable what_to_test
	 var what_to_test   = window.obj_to_validate;

	// If what_to_test is empty, abort and retrun true...
	if (what_to_test.length === 0 )
	{
		return true;
	}
	// If what_to_test is NOT empty, work...
	else
	{
		// Get each object to validate...
		$.each(what_to_test, function (i,v)
		  {

			// Fix for variables with special chars
			v = v.replace( /(\\)/g, "" );
			v = v.replace(  /(:|\.|\[|\]|,|=|@)/g, "\\$1" );

			// Check the value...
			if (validate_chk_value.call(this,v))
			{
				// If the value matches the rule in attribute data-validation-rule
				// of the INPUT, increase the true counter
				trueCount++;
			}
			else
			{
				// If the value doesn't match the rule in attribute data-validation-rule
				// of the INPUT, increase the false counter
			  	falseCount++;
				if ( !$('body').attr('validatefailed') )
				{
					$('body').attr('validatefailed',v);
			  		var x = $(v).offset().top - 50;
			   		jQuery('html,body').animate({scrollTop: x}, 400);
					setTimeout(function(){ $('body').removeAttr('validatefailed'); }, 1000);		   		
				}
			}
		  });
	}
	// If falseCount is equal or greater than 0 something was wrong (initial value is -1)
	if (falseCount >= 0)
	{
	  return false;
	}
	// If trueCount is equal or greater than 0 something was ok - so I expect all was ok
	// as nothing was wrong before with falseCount (initial value is -1)
  if (trueCount >= 0)
  {
	return true;
  }
  // Never should arrive here but if, return false to be sure nothin bad is submitted
  return false;
}

// Function block to remove formatting
var _onPaste_StripFormatting_IEPaste = false;
function validate_OnPaste_StripFormatting(elem, e)
{
	if (e.originalEvent && e.originalEvent.clipboardData && e.originalEvent.clipboardData.getData)
	{
		e.preventDefault();
		var text = e.originalEvent.clipboardData.getData('text/plain');
		window.document.execCommand('insertText', false, text);
	}
	else if (e.clipboardData && e.clipboardData.getData)
	{
		e.preventDefault();
		var text = e.clipboardData.getData('text/plain');
		window.document.execCommand('insertText', false, text);
	}
	else if (window.clipboardData && window.clipboardData.getData)
	{
		// Stop stack overflow
		if (!_onPaste_StripFormatting_IEPaste) {
			_onPaste_StripFormatting_IEPaste = true;
			e.preventDefault();
			window.document.execCommand('ms-pasteTextOnly', false);
		}
		_onPaste_StripFormatting_IEPaste = false;
	}
}

function validate_convert_rule (object, rule)
{
	// Detect and handle special conditions:
	if ( rule.substring(0,8) === "special:" )
	{
		// Convert rule into array
		var rule_array = rule.split(':');
		// Get condition from rule array
		var condition = rule_array[1];
		switch (condition)
		{
			// Condition cases
			case 'any':
				// Accept letters a-z and A-Z
				rule = '^[a-zA-Z]*$';
				break;
			case 'compare-with':
				// If the value of object is the same as in the given object
				// to compare with...
				if( $(rule_array[2]).val() == $(object).val()  )
				{
					// It is the same => replace rule by a rule which is always true
					rule = '$';
				}
				else
				{
					// It is not the same => replace rule by a rule which is always false
					rule = '(?=x)y';
				}
				break;
			case 'alpha':
				// Accept letters a-z and A-Z
				rule = '^[a-zA-Z]*$';
				break;
			case 'alpha-uppercase':
				// Accept uppercase letters A-Z
				rule = '^[A-Z]*$';
				break;
			case 'alpha-lowercase':
				// Accept lowercase letters a-z
				rule = '^[a-z]*$';
				break;
			case 'alphanumeric':
				// Accept letters a-z and A-Z and digits 0-9 
				rule = '^[a-zA-Z0-9]*$';
				break;
			case 'alphanumeric-lowercase':
				// Accept lowercase letters a-z and digits 0-9
				rule = '^[a-z0-9]*$';
				break;
			case 'alphanumeric-uppercase':
				// Accept uppercase letters A-Z and digits 0-9
				rule = '^[A-Z0-9]*$';
				break;

			case 'alpha-ws':
				// Accept letters a-z and A-Z + whitespaces
				rule = '^[a-zA-Z\\s]*$';
				break;
			case 'alpha-uppercase-ws':
				// Accept uppercase letters A-Z + whitespaces
				rule = '^[A-Z\\s]*$';
				break;
			case 'alpha-lowercase-ws':
				// Accept lowercase letters a-z + whitespaces
				rule = '^[a-z\\s]*$';
				break;
			case 'alphanumeric-ws':
				// Accept letters a-z and A-Z and digits 0-9  + whitespaces
				rule = '^[a-zA-Z0-9\\s]*$';
				break;
			case 'alphanumeric-lowercase-ws':
				// Accept lowercase letters a-z and digits 0-9 + whitespaces
				rule = '^[a-z0-9\\s]*$';
				break;
			case 'alphanumeric-uppercase-ws':
				// Accept uppercase letters A-Z and digits 0-9 + whitespaces
				rule = '^[A-Z0-9\\s]*$';
				break;
			case 'digits':
			case 'number':
			case 'numeric':
				// Accept digits
				rule = '^\\d*$';
				break;
			case 'number-exact-digits':
				// Check if exact number of digits is given otherwise default 1
				rule_array[2] = ( typeof rule_array[2] != 'undefined' && !isNaN(parseInt(rule_array[2])) ) ? parseInt(rule_array[2]) : '1';
				rule = '^[0-9]{'+rule_array[2]+'}$';
				break;
			case 'number-min-digits':
				// Check if min digits value is given otherwise default 1
				rule_array[2] = ( typeof rule_array[2] != 'undefined' && !isNaN(parseInt(rule_array[2])) ) ? parseInt(rule_array[2]) : '1';
				rule = '^([0-9]{'+rule_array[2]+'}[0-9]*)$';
				break;
			case 'number-max-digits':
				// Check if max digits value is given otherwise default 1
				rule_array[2] = ( typeof rule_array[2] != 'undefined' && !isNaN(parseInt(rule_array[2])) ) ? parseInt(rule_array[2]) : '1';
				rule = '^[0-9]{1,'+rule_array[2]+'}$';
				break;
			case 'number-min-max-digits':
				// Check if min + max digits values are given otherwise default to 1
				rule_array[2] = ( typeof rule_array[2] != 'undefined' && !isNaN(parseInt(rule_array[2])) ) ? parseInt(rule_array[2]) : '1';
				rule_array[3] = ( typeof rule_array[3] != 'undefined' && !isNaN(parseInt(rule_array[3])) ) ? parseInt(rule_array[3]) : '1';
				rule_array[3] = ( rule_array[3] > rule_array[2]  ) ? rule_array[3] : rule_array[3] = rule_array[2];
				rule = '^[0-9]{'+rule_array[2]+','+rule_array[3]+'}$';
				break;
			case 'number-exact-value':
				// Check if exact number is given 
				rule_array[2] = rule_array[2].replace(  /,/g, "." );
				rule_array[2] = ( typeof rule_array[2] != 'undefined' && !isNaN(parseFloat(rule_array[2])) ) ? parseFloat(rule_array[2]) : '(?=x)y';
				rule = '^'+rule_array[2]+'$';
				break;
			case 'number-min-value':
				// Check if number is minumum 
				var object_value = Math.fround( parseFloat( $(object).val().replace(  /,/g, "." ) ) );
				var rule_value	 = Math.fround( parseFloat( rule_array[2].replace(  /,/g, "." ) ) );
				rule = ( object_value >= rule_value ) ? '^[\\+\\-]?\\d+([\\.\\,]\\d+)?$' : '(?=x)y';
				break;
			case 'number-max-value':
				// Check if number is maximum
				var object_value = Math.fround( parseFloat( $(object).val().replace(  /,/g, "." ) ) );
				var rule_value	 = Math.fround( parseFloat( rule_array[2].replace(  /,/g, "." ) ) );
				rule = ( object_value <= rule_value ) ? '^[\\+\\-]?\\d+([\\.\\,]\\d+)?$' : '(?=x)y';
				break;
			case 'number-min-max-value':
				// Check if min + max digits values are given otherwise default to 1
				var object_value = Math.fround( parseFloat( $(object).val().replace(  /,/g, "." ) ) );
				var rule_value1	 = Math.fround( parseFloat( rule_array[2].replace(  /,/g, "." ) ) );
				var rule_value2	 = Math.fround( parseFloat( rule_array[3].replace(  /,/g, "." ) ) );
				rule = ( ( object_value >= rule_value1 ) &&  ( object_value <= rule_value2 ) ) ? '^[\\+\\-]?\\d+([\\.\\,]\\d+)?$' : '(?=x)y';
				break;
			case 'email':
				// Check if email 
				// (?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])
				rule ='^(([^<>()\\[\\]\\\\.,;:\\s@"]+(\\.[^<>()\\[\\]\\\\.,;:\\s@"]+)*)|(".+"))@((\\[[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}])|(([a-zA-Z\\-0-9]+\\.)+[a-zA-Z]{2,}))$';
				break;
			case 'hostname':
				// Check if hostname following RFC1123
				rule ='^(?![0-9]+$)(?!.*-$)(?!-)[a-zA-Z0-9-]{1,63}$';
				break;
			case 'ipaddr':
				// Check if IP Address e.g. 123.34.56.78
				rule ='^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$';
				break;
			case 'hostname_or_ipaddr':
				// Check if IP Address e.g. 123.34.56.78 or hostname
				rule ='^(?![0-9]+$)(?!.*-$)(?!-)[a-zA-Z0-9-]{1,63}$|^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$';
				break;
			case 'domainname_or_ipaddr':
				// Check if IP Address e.g. 123.34.56.78 or domainname incl. subdomains
				rule ='^([a-zA-Z0-9][a-zA-Z0-9-_]*\\.)*(([a-zA-Z]{1})|([a-zA-Z]{1}[a-zA-Z]{1})|([a-zA-Z]{1}[0-9]{1})|([0-9]{1}[a-zA-Z]{1})|([a-zA-Z0-9][a-zA-Z0-9-_]{1,61}[a-zA-Z0-9]))\\.([a-zA-Z]{2,6}|[a-zA-Z0-9-]{2,30}\\.[a-zA-Z]{2,3})$|^(?![0-9]+$)(?!.*-$)(?!-)[a-zA-Z0-9-]{1,63}$|^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$';
				break;
			case 'netmask':
			case 'ipmask':
				// Check if IP Mask e.g. 255.255.255.0
				rule ='^(((255\\.){3}(254|252|248|240|224|192|128|0+))|((255\\.){2}(255|254|252|248|240|224|192|128|0+)\\.0)|((255\\.)(255|254|252|248|240|224|192|128|0+)(\\.0+){2})|((255|252|248|240|224|192|128|0+)(\\.0+){3}))$';
				break;
			case 'port':
			case 'ipport':
				// Check if IP Port 1-65535
				rule ='^(([1-9]{1}|[1-9][0-9]{1,3})|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$';
				break;
			case 'ssid':
				// Check if WLAN SSID 
				rule ='^([\\w\\u0020\\u0024\\u0040\\u005e\\u0060\\u002c\\u007c\\u0025\\u003b\\u002e\\u007e\\u0028\\u0029\\u002f\\u005c\\u007b\\u007d\\u003a\\u003f\\u005b\\u005d\\u003d\\u002d\\u002b\\u00f5\\u0023\\u0021]{1,32})$';
				break;
			case 'wpa':
				// Check if WLAN WPA Key 
				rule ='^([\\u0020-\\u007e\\u00a0-\\u00ff]{8,64})$';
				break;
			case 'url':
				// Check if URL
				rule = '^([hH][tT][tT][pP][sS]\?\|[sS]\?[fF][tT][pP])\:\\/\\/(((([a-zA-Z]|\\d|-|\\.|_|~|[\\u00A0-\\uD7FF\\uF900-\\uFDCF\\uFDF0-\\uFFEF])|(%[\\da-fA-F]{2})|[!\\$&\'\\(\\)\\*\\+,;=]|\:)*@)?(((\\d|[1-9]\\d|1\\d\\d|2[0-4]\\d|25[0-5])\\.(\\d|[1-9]\\d|1\\d\\d|2[0-4]\\d|25[0-5])\\.(\\d|[1-9]\\d|1\\d\\d|2[0-4]\\d|25[0-5])\\.(\\d|[1-9]\\d|1\\d\\d|2[0-4]\\d|25[0-5]))|((([a-zA-Z]|\\d|[\\u00A0-\\uD7FF\\uF900-\\uFDCF\\uFDF0-\\uFFEF])|(([a-zA-Z]|\\d|[\\u00A0-\\uD7FF\\uF900-\\uFDCF\\uFDF0-\\uFFEF])([a-zA-Z]|\\d|-|\\.|_|~|[\\u00A0-\\uD7FF\\uF900-\\uFDCF\\uFDF0-\\uFFEF])*([a-zA-Z]|\\d|[\\u00A0-\\uD7FF\\uF900-\\uFDCF\\uFDF0-\\uFFEF])))\\.)+(([a-zA-Z]|[\\u00A0-\\uD7FF\\uF900-\\uFDCF\\uFDF0-\\uFFEF])|(([a-zA-Z]|[\\u00A0-\\uD7FF\\uF900-\\uFDCF\\uFDF0-\\uFFEF])([a-zA-Z]|\\d|-|\\.|_|~|[\\u00A0-\\uD7FF\\uF900-\\uFDCF\\uFDF0-\\uFFEF])*([a-zA-Z]|[\\u00A0-\\uD7FF\\uF900-\\uFDCF\\uFDF0-\\uFFEF])))\\.?)(:\\d*)?)(\\/((([a-zA-Z]|\\d|-|\\.|_|~|[\\u00A0-\\uD7FF\\uF900-\\uFDCF\\uFDF0-\\uFFEF])|(%[\\da-fA-F]{2})|[!\\$&\'\\(\\)\\*\\+,;=]|:|@)+(\\/(([a-zA-Z]|\\d|-|\\.|_|~|[\\u00A0-\\uD7FF\\uF900-\\uFDCF\\uFDF0-\\uFFEF])|(%[\\da-fA-F]{2})|[!\\$&\'\\(\\)\\*\\+,;=]|:|@)*)*)?)?(\\?((([a-zA-Z]|\\d|-|\\.|_|~|[\\u00A0-\\uD7FF\\uF900-\\uFDCF\\uFDF0-\\uFFEF])|(%[\\da-fA-F]{2})|[!\\$&\'\\(\\)\\*\\+,;=]|:|@)|[\\uE000-\\uF8FF]|\\/|\\?)*)?(#((([a-zA-Z]|\\d|-|\\.|_|~|[\\u00A0-\\uD7FF\\uF900-\\uFDCF\\uFDF0-\\uFFEF])|(%[\\da-fA-F]{2})|[!\\$&\'\\(\\)\\*\\+,;=]|:|@)|\\/|\\?)*)?$';
				break;
			case 'emails':
				// Check if eMail addresses
				rule = '^(^[a-zA-Z0-9.!#$%&\u2019*+\\/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\\.[a-zA-Z0-9-]+){1}$)|^([a-zA-Z0-9.!#$%&\u2019*+\\/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\\.[a-zA-Z0-9-]+)*\\;)*([a-zA-Z0-9.!#$%&\u2019*+\\/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\\.[a-zA-Z0-9-]+)*)$';
				break;
			case 'email':
				// Check if eMail address
				rule = '^(^[a-zA-Z0-9.!#$%&\u2019*+\\/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\\.[a-zA-Z0-9-]+)*$';
				break;
			case 'alphanumeric-accented-ws':
				// Accept letters a-z and A-Z and digits 0-9  + whitespaces + accented chars + _- . ! ?
				rule = '^([a-zA-Z0-9\\[\\]\\(\\)\\?\\!\\_\\-\\.\\s\\u00C0-\\u017F])*$';
				break;
			default:
				// Unknown condition => replace rule by a rule which is always false
				console.log("Error: Unknown condition! Resulting rule: " + rule + " (false)");
				rule = '(?=x)y';
		}
	}
	return rule;
}

function validate_chk_value( object,evt,rule )
{
	// This function does the checking against the regular expression rule
	// If the event is not defined, set it to 0
	// (This happens if called from the code itself)
	evt = evt || 0;

	// Fix for variables with special chars
	object = object.replace( /(\\)/g, "" );
	object = object.replace(  /(:|\.|\[|\]|,|=|@)/g, "\\$1" );
	// If the rule is not given when calling the function, get the value
	// in attribute data-validation-rule of the INPUT
	var rule = rule || $(object).attr("data-validation-rule");
	// If the rule is neither given when calling the function, not in the value
	// of attribute data-validation-rule of the INPUT define a rule which
	// returns always false to be sure nothing bad is validated by mistake
	rule = rule || '(?=a)b';
	rule = validate_convert_rule(object , rule);

	// Special case or
	if ( $(object).attr('data-validation-or') )
	{
	    var or_object = $(object).attr('data-validation-or');
		var ruleA = new RegExp(validate_convert_rule ( or_object ,$(or_object).attr('data-validation-rule')));
        var ruleB = new RegExp(validate_convert_rule ( object ,$(object).attr('data-validation-rule')));
		if ( ruleA.test($(or_object).val()) || ruleB.test($(object).val()) )
		{
			if ( ruleA.test($(or_object).val()) )
			{
				$(object).val('');
			}
			if ( ruleB.test($(object).val())  )
			{
				$(or_object).val('');
			}
			rule = '$';
		    $('#error-msg-'+or_object.substring(1)).fadeOut(100);
			// If coloring is not disabled change the color
			if ( $(or_object).attr('data-validation-coloring') != 'off' )
			{
				if ( $(or_object).val() == '' )
				{
					// Set color for nocolor
					$( or_object ).css("background-color",$(or_object).attr("original-background-color"));
				}
				else
				{
					// Set color for ok
					$( or_object ).css("background-color","#C0FFC0");
				}
			}
			else
			{
				// Set color for nocolor
				$( or_object ).css("background-color",$(or_object).attr("original-background-color"));
			}
		}
	}

	// Convert the rule string into a regular expression
	rule = new RegExp(rule);

	// Check, if the INPUT value matches the rule
	if( !rule.test($(object).val()))
	{
		// The rule doesn't match => That's bad
		// If the validate_chk_value was called when leaving a field,
		// or no event is given, apply the following:
		if (evt.type == "blur"  || evt === 0 )
		{
			// Get the position of the INPUT on the page
			var offset = $(object).position();
			// Check if object still there
			if (typeof offset === 'undefined')
			{
				// If what_to_test is empty, no need to remove
				if (typeof single_object !== 'undefined') 
				{
					// On page switch remove old values
					window.obj_to_validate.splice($.inArray(single_object, obj_to_validate),1);
				}
			}
			else
			{
				// Set the position of the tooltip below INPUT
				$('#error-msg-'+object.substring(1)).css({'z-index':1000, 'margin': '-1px', 'margin-top':'auto', 'padding': '5px', 'border': '1px solid #FF0000', 'border-radius': '0px 0px 8px 8px', 'color': '#FF0000', 'background-color': '#FFFFC0', 'white-space': 'normal'});
				$(".ui-input-text").css("margin-bottom",0);
				$('#error-msg-'+object.substring(1)).css('margin-top','-1px');

				// Remove the bottom round corners of input to connect the error message 
				$(object).css({'border-radius': '8px 8px 0px 0px'});

				// Show the tooltip
				$('#error-msg-'+object.substring(1)).fadeIn(500);
			}
		}
		// If coloring is not disabled change the color
		if ( $(object).attr('data-validation-coloring') != 'off' )
		{
			if ( $(object).val() == '' )
			{
				// Set color for nocolor
				$( object ).css("background-color",$(object).attr("original-background-color"));
			}
			else
			{
				// Set color for error
				$( object ).css("background-color","#FFC0C0");
			}
		}
		else
		{
			// Set color for nocolor
			$( object ).css("background-color",$(object).attr("original-background-color"));
		}

		// Return false to the caller
		return false
	}
	else
	{
		// The rule matches => That's good

		// If coloring is not disabled change the color
		if ( $(object).attr('data-validation-coloring') != 'off' )
		{
			if ( $(object).val() == '' )
			{
				// Set color for nocolor
				$( object ).css("background-color",$(object).attr("original-background-color"));
			}
			else
			{
				// Set color for ok
				$( object ).css("background-color","#C0FFC0");
			}
		}
		else
		{
			// Set color for nocolor
			$( object ).css("background-color",$(object).attr("original-background-color"));
		}

		// Hide the tooltip
		$('#error-msg-'+object.substring(1)).fadeOut(100);

		// Add the bottom round corners of input after disconnecting the error message 
		$(object).css({'border-radius': 'inherit'});

		// Return false to the caller
		return true
	}
} 

function validate_chk_object( obj_to_validate )
{
	// Function to define (add) which objects must have
	// correct values to be able to submit the form
	// Check the given variable. If not okay, create an empty array
	var obj_to_validate = ( typeof obj_to_validate != 'undefined' && obj_to_validate instanceof Array ) ? obj_to_validate : [];

	// Go through each object ...
	$.each(obj_to_validate, function(i, obj)
	{
		// Fix for variables with special chars
		obj = obj.replace( /(\\)/g, "" );
		obj = obj.replace(  /(:|\.|\[|\]|,|=|@)/g, "\\$1" );

		// Put the object into the global array window.obj_to_validate
		window.obj_to_validate.push(obj);
	});
	// Remove duplicates from the global array window.obj_to_validate
	window.obj_to_validate = jQuery.unique( window.obj_to_validate );
	// Reorganize the tooltips
	validate_place_tooltips ();
}
function validate_clean_objects( to_clean )
{ 
	// Function to define (remove) which objects must NOT have
	// correct values any longer to be able to submit the form
	// Check the given variable. If not okay, create an empty array
	var to_clean = ( typeof to_clean != 'undefined' && to_clean instanceof Array ) ? to_clean : [];

	// Go through each object ...
	$.each(to_clean, function(i, object)
	{
		// Fix for variables with special chars
		object = object.replace( /(\\)/g, "" );
		object = object.replace(  /(:|\.|\[|\]|,|=|@)/g, "\\$1" );

		// Delete the value in the input field
		$(object).val('');
		// Hide the tooltip
		$('#error-msg-'+object.substring(1)).fadeOut(100);

		// Set color for nocolor
		$( object ).css("background-color",$(object).attr("original-background-color"));

		// Remove the object from the global array window.obj_to_validate
		window.obj_to_validate.splice($.inArray(object, obj_to_validate),1);
	});
	// Reorganize the tooltips
	validate_place_tooltips ();
}

function validate_place_tooltips ()
{
	// Function to reorganize the tooltips
	// Remove duplicates from window.obj_to_validate
	window.obj_to_validate = jQuery.unique( window.obj_to_validate );
	// Go through each object ...
	$.each(window.obj_to_validate, function(i, single_object)
	{
		// Fix for variables with special chars
		single_object = single_object.replace( /(\\)/g, "" );
		single_object = single_object.replace(  /(:|\.|\[|\]|,|=|@)/g, "\\$1" );

		// Correct the position of the tooltip after 450 ms from now
		setTimeout( function()
		{
			// Get the INPUT position
			var offset = $(single_object).position();
			// Check if object still there
			if (typeof offset === 'undefined')
			{
				// On page switch remove old values
				window.obj_to_validate.splice($.inArray(single_object, obj_to_validate),1);
			}
		}, 500);
	});
	return;
}
