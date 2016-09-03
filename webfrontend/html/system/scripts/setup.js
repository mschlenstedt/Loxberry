$(document).ready(function () {

  // Set language
  var lang = $('#lang').html();

  // Show loading animation while ajax events
  $(this).ajaxStart(function() {
    $("#overlay").show();
  });
 
  $(this).ajaxStop(function() {
    $("#overlay").hide();
  });

  // Submit Language Selection
  $('#btnlang').click( function() {
    $("#overlay").show();
    lang_form.submit();
  });

  // Setup Assistent: Scan-Button for Miniserver IP
  $('#btnnetscan').click( function(e) {
    $('#testurl').html('Scanning...');
    e.preventDefault();
    $.ajax({
      contentType: "application/x-www-form-urlencoded; charset=iso-8859-15",
      type: "GET",
      url: "/admin/system/tools/netscan.cgi",
      data: "data",
      success: function(data){
        data.replace(/\r|\n/g, "");
        $('#miniserverip1').empty();
        if (data.length < 3) {
          if (lang == "de"){
            var url = 'Keinen Miniserver gefunden';
          } else {
            var url = 'No Miniserver found';
          }
        } else {
        
        $("#miniserveriprow1").attr( "ipaddr" , data );
        $("#miniserverportrow1").attr( "portaddr" , "80");
        $("#useclouddns1").prop("checked", false);
        $("#useclouddns1").trigger( "change" );
        //$("#miniserverport1").value = "80";

          if (lang == "de"){
            var url = '<a href="http://' + data + '" target="_blank">Gefundene IP-Adresse testen</a>';
          } else {
            var url = '<a href="http://' + data + '" target="_blank">Test found IP-Address</a>';
          }
        }
        $('#testurl').html(url);
      }
    });
  });

});

