/* Loxberry webfrontend/html/system/scripts/validate.js 19.01.2018 19:15:55 */

function validate_enable ( object )
{
	// This function is called from the code to enable validation for this object
	// Create target div for the tooltip - it's named error-msg-<object-id> and inserted after <object-id> (INPUT) which must exists in the HTML page
	$( '<div style="display:none;" id="error-msg-'+object.substring(1)+'">'+$(object).attr('data-validation-error-msg')+'</div>' ).insertAfter( $( object ) );

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
		if (!validate_all())
		{
			// Prevent submitting the form.
			e.preventDefault();
		}
	});

	// Adding an event handler if someone pastes a value into the INPUT
	$(object).on('paste', function(e)
	{
		// In case of pasting values, remove any formatting
		validate_OnPaste_StripFormatting(this, event);
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

function validate_chk_value( object,evt,rule )
{
	// This function does the checking against the regular expression rule
	// If the event is not defined, set it to 0
	// (This happens if called from the code itself)
	evt = evt || 0;
	// If the rule is not given when calling the function, get the value
	// in attribute data-validation-rule of the INPUT
	var rule = rule || $(object).attr("data-validation-rule");
	// If the rule is neither given when calling the function, not in the value
	// of attribute data-validation-rule of the INPUT define a rule which
	// returns always false to be sure nothing bad is validated by mistake
	rule = rule || '(?=a)b';
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
			default:
				// Unknown condition => replace rule by a rule which is always false
				rule = '(?=x)y';
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
				// On page switch remove old values
				window.obj_to_validate.splice($.inArray(single_object, obj_to_validate),1);
			}
			else
			{
				// Set the position of the tooltip below INPUT
				$('#error-msg-'+object.substring(1)).css({'margin': '-1px', 'padding': '5px', 'border': '1px solid #FF0000', 'border-radius': '0px 0px 8px 8px', 'color': '#FF0000', 'background-color': '#FFFFC0', 'white-space': 'normal'});

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
