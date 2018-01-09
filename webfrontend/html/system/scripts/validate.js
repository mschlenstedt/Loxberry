function validate_enable ( object ) 
{
	if($("#page_content").length == 0) 
	{
		$( "body" ).append($('<div id="page_content" class="page_content"></div>'));
	}
	$( ".page_content" ).append($('<div style="display:none;" id="error-msg-'+object.substring(1)+'">'+$(object).attr('data-validation-error-msg')+'</div>'));
	$( '#error-msg-'+object.substring(1) ).css('display','none');
	window.obj_to_validate = ( typeof window.obj_to_validate != 'undefined' && window.obj_to_validate instanceof Array ) ? window.obj_to_validate : [];
	$( $(object).closest('form') ).submit(function(e) 
	{
		if (!validate_all())
		{
			e.preventDefault();
		}
	});
	$(object+'_div').on('paste', function(e)
	{
		validate_OnPaste_StripFormatting(this, event);
	});
	$(object+'_div').on('blur keyup input ', function(e)
	{
		if (e.type == "blur" )
		{
			$(this).removeClass("ui-focus").addClass("ui-shadow-inset");
		}
		else 
		{
			$(this).removeClass("ui-shadow-inset").addClass("ui-focus");
		}
		if ( $(this).hasClass('param_ok') )
		{
			$(this).removeClass('param_ok').addClass('param_ok');
			$('#error-msg-'+object.substring(1)).fadeOut(400);
		}
		else
		{
			$(this).removeClass('param_error').addClass('param_error');
		} 
		
		validate_chk_value( object,e );
	});
	$(object).attr('value',$(object+"_div").text());
}

function validate_all()
{
  var trueCount=-1;
  var falseCount=-1;
  var what_to_test = window.obj_to_validate;
	$.each(what_to_test, function (i,v) 
	  {
  	var saveval = $(v+'_div').text();
  	$(v+'_div').text($(v).val());
    if (validate_chk_value.call(this,v)) {
      trueCount++;
    }
    else {
      falseCount++;
    }
  	$(this+'_div').text(saveval);
  	saveval='';
    });
    
    if (falseCount >= 0) 
    {
	    return false;
    }
    if (trueCount >= 0) 
    {
	    return true;
    }
    return false;
}	

var _onPaste_StripFormatting_IEPaste = false;
function validate_OnPaste_StripFormatting(elem, e) {

    if (e.originalEvent && e.originalEvent.clipboardData && e.originalEvent.clipboardData.getData) {
        e.preventDefault();
        var text = e.originalEvent.clipboardData.getData('text/plain');
        window.document.execCommand('insertText', false, text);
    }
    else if (e.clipboardData && e.clipboardData.getData) {
        e.preventDefault();
        var text = e.clipboardData.getData('text/plain');
        window.document.execCommand('insertText', false, text);
    }
    else if (window.clipboardData && window.clipboardData.getData) {
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
	evt = evt || 0;
	var rule = rule || $(object).attr("data-validation-rule");
	rule = rule || "(?=a)b";
	rule = new RegExp(rule);
	if( !rule.test( $(object+'_div').text() )  )
	{
		if (evt.type == "blur"  || evt === 0 )
		{ 
			var offset = $(object+'_div').offset();  
			$('#error-msg-'+object.substring(1)).css({'padding': '5px', 'border': '1px solid #FF0000', 'border-radius': '5px', 'color': '#FF0000', 'background-color': '#FFFFC0', 'z-index': 1000, 'top': offset.top - 30, 'left': offset.left, 'position':'absolute'});
			$('#error-msg-'+object.substring(1)).fadeIn(400);
		}
			$(object+'_div').removeClass('param_ok').addClass('param_error');
			$(object).val('');
		return false
	}
	else
	{
		$(object+'_div').removeClass('param_error').addClass('param_ok');
		$(object).val($(object+'_div').text());
		return true
	}
}

function validate_chk_object( obj_to_validate ) 
{
	obj_to_validate = ( typeof obj_to_validate != 'undefined' && obj_to_validate instanceof Array ) ? obj_to_validate : [];
	$.each(obj_to_validate, function(i, obj)
	{
	    window.obj_to_validate.push(obj);
	});
	window.obj_to_validate = jQuery.unique( window.obj_to_validate );
	$.each(window.obj_to_validate, function(i, obj)
	{
		setTimeout( function() 
		{
			var offset = $(obj+'_div').offset();
			$('#error-msg-'+obj.substring(1)).css({'top': offset.top - 30, 'left': offset.left});
	  }, 150);
	});
}
function validate_clean_objects( to_clean ) 
{
	to_clean = ( typeof to_clean != 'undefined' && to_clean instanceof Array ) ? to_clean : [];
	$.each(to_clean, function(i, obj)
	{
		$(obj).val('');
		$(obj+"_div").text('');
		$('#error-msg-'+obj.substring(1)).fadeOut(100);
		$(obj+"_div").removeClass('param_error').addClass('param_ok');
		window.obj_to_validate.splice($.inArray(obj, obj_to_validate),1);
	});
	window.obj_to_validate = jQuery.unique( window.obj_to_validate );
	$.each(window.obj_to_validate, function(i, obj)
	{
		setTimeout( function() 
		{ 
			var offset = $(obj+'_div').offset();  
			$('#error-msg-'+obj.substring(1)).css({'top': offset.top - 30, 'left': offset.left});
		}, 450);
	});
}
