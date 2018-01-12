function validate_enable ( object ) 
{ 
	// This function is called from the code to enable validation for this object 
  // Create target div for the tooltip - it's named error-msg-<object-id> and inserted after <object-id>_div (INPUT-DIV) which must exists in the HTML page
	$( '<div style="display:none;" id="error-msg-'+object.substring(1)+'">'+$(object).attr('data-validation-error-msg')+'</div>' ).insertAfter( $( object+'_div' ) );
	// Prevent return key
	$(object+"_div").keypress(function(e){ return e.which != 13; });
	
	// Handling screen resizing...
	$( window ).resize(function() 
	{
		// Get position of the related INPUT-DIV
		var offset = $(object+'_div').position();  
		// Set position of tooltip below the related INPUT-DIV
		$('#error-msg-'+object.substring(1)).css({'width': $(object+'_div').width(), 'top': offset.top + 40 , 'left': offset.left});
	});
	// The global variable window.obj_to_validate holds all objects which prevent submitting the form, 
	// if the content doesn't match the rule in parameter data-validation-rule of the INPUT-DIV
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
		else
		{
			console.log("Submitting form");
		}	
	});
	// Adding an event handler if someone pastes a value into the INPUT-DIV
	$(object+'_div').on('paste', function(e)
	{
		// In case of pasting values, remove any formatting
		validate_OnPaste_StripFormatting(this, event);
	});
	// Adding an event handler if someone leaves, enters the INPUT-DIV or 
	// lift the finger from a key or input something into the INPUT-DIV 
	$(object+'_div').on('blur keyup input focusin', function(e)
	{
		// In case of leaving the INPUT-DIV (blur)  
		if (e.type == "blur" )
		{
			// Remove the focus CSS
			$(this).removeClass("ui-focus").addClass("ui-shadow-inset");
		}
		else 
		{
			// For all other cases (keyup input focusin) add the focus CSS
			$(this).removeClass("ui-shadow-inset").addClass("ui-focus");
		}
		// If the object has CSS param_ok enabled ...
		if ( $(this).hasClass('param_ok') )
		{
			// ...remove the CSS param_ok and add it at the end to prevent overwriting by other CSS rules
			$(this).removeClass('param_ok').addClass('param_ok');
			// Hide the tooltip 
			$('#error-msg-'+object.substring(1)).fadeOut(400);
		}
		else
		{
			// ...otherwise remove the CSS param_error and add it at the end to prevent overwriting by other CSS rules
			$(this).removeClass('param_error').addClass('param_error');
		} 
		// Check the current value of the INPUT-DIV 
		validate_chk_value( object,e );
	});
	// Put the value in the INPUT-DIV into the hidden INPUT field of the HTML page.
	// This is the value, which is really sent to the server when submitting the form. 
	$(object).attr('value',$(object+"_div").text());
}

function validate_all()
{
	// This function validates all INPUT-DIV which were added to the array window.obj_to_validate
	// by calling the validate_chk_object(['<OBJECT>']); from the HTML page
	// The function validate_all() returns true only, if all fields are correct filled.
	// As soon as one field is wrong, false is returned. If the array window.obj_to_validate is
	// empty, true is returned.
	var trueCount			=-1;
  var falseCount		=-1;
  // Put the array window.obj_to_validate in to the local variable what_to_test
  var what_to_test 	= window.obj_to_validate;
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
		  	// Write the value from hidden input field into the INPUT-DIV 
		  	// to have both fields consistent before starting the check
		  	// and show the user the real value which is validated as the
		  	// hidden INPUT field is not visible
			  $(v+'_div').text($(v).val());
		    // Check the value...
		    if (validate_chk_value.call(this,v)) 
		    {
		    	// If the value matches the rule in attribute data-validation-rule 
		    	// of the INPUT-DIV, increase the true counter
		      trueCount++;
		    }
		    else 
		    {
	 	    	// If the value doesn't match the rule in attribute data-validation-rule 
		    	// of the INPUT-DIV, increase the false counter
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
	// in attribute data-validation-rule of the INPUT-DIV 
	var rule = rule || $(object).attr("data-validation-rule");
	// If the rule is neither given when calling the function, not in the value 
	// of attribute data-validation-rule of the INPUT-DIV define a rule which
	// returns always false to be sure nothing bad is validated by mistake
	rule = rule || "(?=a)b";
	// Convert the rule string into a regular expression
	rule = new RegExp(rule);
	// Check, if the INPUT-DIV value matches the rule
	if( !rule.test( $(object+'_div').text() )  )
	{
		// The rule doesn't match => That's bad
		// If the validate_chk_value was called when leaving a field,
		// or no event is given, apply the following:
		if (evt.type == "blur"  || evt === 0 )
		{ 
			// Get the position of the INPUT-DIV on the page
			var offset = $(object+'_div').position();  
			// Set the position of the tooltip below INPUT-DIV 
			$('#error-msg-'+object.substring(1)).css({'padding': '5px', 'border': '1px solid #FF0000', 'border-radius': '5px', 'color': '#FF0000', 'background-color': '#FFFFC0', 'z-index': 1000, 'width': $(object+'_div').width(), 'top': offset.top + 40, 'left': offset.left, 'position':'absolute'});
			// Show the tooltip 
			$('#error-msg-'+object.substring(1)).fadeIn(400);
		}
		// Remove the CSS for param_ok and add param_error instead
		$(object+'_div').removeClass('param_ok').addClass('param_error');
		// Remove the (invalid) value from the hidden input box
		$(object).val('');
		// Return false to the caller
		return false
	}
	else
	{
		// The rule matches => That's good
		// Remove the CSS for param_error and add param_ok instead
		$(object+'_div').removeClass('param_error').addClass('param_ok');
		// Put the (validated) value into the hidden input box
		$(object).val($(object+'_div').text());
		// Hide the tooltip 
  	$('#error-msg-'+object.substring(1)).fadeOut(400);
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
		// Delete the value in the hidden input field 
		$(object).val('');
		// Delete the value in the INPUT-DIV
		$(object+"_div").text('');
		// Hide the tooltip
		$('#error-msg-'+object.substring(1)).fadeOut(100);
		// Remove the CSS for param_error and add param_ok
		$(object+"_div").removeClass('param_error').addClass('param_ok');
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
			// Get the INPUT-DIV position 
			var offset = $(single_object+'_div').position();  
			// Place the tooltip below the INPUT-DIV 
			$('#error-msg-'+single_object.substring(1)).css({'padding': '5px', 'border': '1px solid #FF0000', 'border-radius': '5px', 'color': '#FF0000', 'background-color': '#FFFFC0', 'z-index': 1000, 'width': $(single_object+'_div').width(), 'top': offset.top + 40, 'left': offset.left, 'position':'absolute'});
		}, 450);
	});
	return;
}
