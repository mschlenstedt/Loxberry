$(document).ready(function () {

 // function checknetwork() {
    //alert ('ja');
    //var state = $("#netzwerkanschluss_eth0").val();
    //if ( $('#net_eth').checked ) {
    //  alert ('Eth');
    //  //$('#btnlistnetworks').addClass('ui-disabled');
    //}
    //else {
    //  //$('#btnlistnetworks').removeClass('ui-disabled');
    //  alert ('WLAN');
    // }
  //}

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

  // Setup Assistent Step 02: Scan-Button for Miniserver IP
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
        if (data == "") {
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

  // Step 02: Search-Button for Address
  $('#btnaddressscan').click( function(e) {
    e.preventDefault();
    var data = 'query='+$("#address").val()+'&lang='+lang;
    $.ajax({
      contentType: "application/x-www-form-urlencoded; charset=iso-8859-15",
      type: "POST",
      url: "/admin/tools/geolocation.cgi",
      data: data,
      success: function(data){
        $('#addressresults').empty();
        $('#addressresults').html(data);
      }
    });
  });

  // Step 03: Test Mailserver
  $('#btntestsmtp').click( function(e) {
    e.preventDefault();
    var data = 'email='+$("#email").val()+'&smtpserver='+$("#smtpserver").val()+'&smtpauth='+$("#smtpauth").val()+'&smtpcrypt='+$("#smtpcrypt").val()+'&smtpuser='+$("#smtpuser").val()+'&smtppass='+$("#smtppass").val()+'&smtpport='+$("#smtpport").val()+'&lang='+lang;
    $.ajax({
      contentType: "application/x-www-form-urlencoded; charset=iso-8859-15",
      type: "POST",
      url: "/admin/tools/smtptest.cgi",
      data: data,
      success: function(data){
        $('#smtpresults').empty();
        $('#smtpresults').html(data);
      }
    });
  });




  return false;

});

