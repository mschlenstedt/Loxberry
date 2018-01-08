			function clean_values( to_clean ) 
			{
				$('#form-error-message').hide();
				to_clean = ( typeof to_clean != 'undefined' && to_clean instanceof Array ) ? to_clean : [];
				$.each(to_clean, function(i, obj)
				{
					$(obj).val('');
					$(obj+"_div").text('');
				});
			}
			
			function validate_form()
			{
			  var trueCount=-1;
        var falseCount=-1;
        var what_to_test = window.to_validate;
     		$.each(what_to_test, function (i,v) 
     		  {
   		  	var saveval = $(v+'_div').text();
   		  	$(v+'_div').text($(v).val());
          if (valid_value.call(this,v)) {
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
      function OnPaste_StripFormatting(elem, e) {

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
			function enable_validation( object ) 
			{
				window.to_validate = ( typeof window.to_validate != 'undefined' && window.to_validate instanceof Array ) ? window.to_validate : [];
				$( $(object).closest('form') ).submit(function(e) 
				{
					if (!validate_form())
					{
						e.preventDefault();
					}
				});

				$(object+'_div').on('paste', function(e)
				{
					OnPaste_StripFormatting(this, event);
				});

				$(object+'_div').on('blur keyup input focusin', function(e)
				{
					$(object).attr('value',$(this).text());
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
					}
					else
					{
						$(this).removeClass('param_error').addClass('param_error');
					} 
					
					valid_value( object,e );
				});
			}
			function valid_value( object,evt,rule ) 
			{
				evt = evt || 0;
				var rule = rule || $(object).attr("data-validation-rule");
				rule = rule || "(?=a)b";
				rule = new RegExp(rule);
				if( !rule.test( $(object+'_div').text() )  )
				{
					if (evt.type == "blur"  || evt === 0 )
					{ 
						$('#form-error-message').html( $(object).attr('data-validation-error-msg'));
						var offset = $(object+'_div').offset();  
						$('#form-error-message').fadeIn(400);
						$('#form-error-message').css({'padding': '5px', 'border': '1px solid #FF0000', 'border-radius': '5px', 'color': '#FF0000', 'background-color': '#FFFFC0', 'z-index': 1000, 'top': offset.top - 35, 'left': offset.left, 'position':'absolute'});
						setTimeout( function() { $('#form-error-message').fadeOut(400); }, 3000);
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
