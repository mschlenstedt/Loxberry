			function clean_values( to_clean ) 
			{
				$('#form-error-message').hide();
				$.each(to_clean.split(" "), function(i, obj)
				{
					$("#"+obj).attr('value','');
				});
			}
			function enable_validation( object ) 
			{
				$(object+'_div').on('blur keyup input focusin', function(e)
				{
					$(object).attr('value',$(this).text());
					if (e.type == "blur" || e.type == "paste" )
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
			function valid_value( object,e ) 
			{
				var rule = new RegExp($(object).attr("data-validation-rule"));
				if( !rule.test( $(object+'_div').text() ) )
				{
					if (e.type == "blur" )
					{ 
						$('#form-error-message').html( $(object).attr('data-validation-error-msg'));
						var offset = $(object+'_div').offset();  
						$('#form-error-message').fadeIn(400);
						$('#form-error-message').css({'padding': '5px', 'border': '1px solid #FF0000', 'border-radius': '5px', 'color': '#FF0000', 'background-color': '#FFFFC0', 'z-index': 1000, 'top': offset.top - 35, 'left': offset.left, 'position':'absolute'});
						setTimeout( function() { $('#form-error-message').fadeOut(400); }, 3000);
					}
						$(object+'_div').removeClass('param_ok').addClass('param_error');
						$(object).val('');
						$($(object).closest('form')).submit(function(e){
						        e.preventDefault();
						    });
					return false
				}
				else
				{
					$(object+'_div').removeClass('param_error').addClass('param_ok');
					$(object).val($(object+'_div').text());
					return true
				}
			}
