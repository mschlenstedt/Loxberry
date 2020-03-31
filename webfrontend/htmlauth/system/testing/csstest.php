<?php
require_once "loxberry_web.php";
  
// This will read your language files to the array $L
$template_title = "Top Plugin";
$helplink = "http://www.loxwiki.eu:80/x/2wzL";
$helptemplate = "help.html";
  
LBWeb::lbheader($template_title, $helplink, $helptemplate);
 
// This is the main area for your plugin
?>

Hallo

<style>
	.ui-slider-track,
	.ui-flipswitch.ui-bar-inherit {
		background-color: #EEEEEE !important;
		color:black !important;
		text-shadow: none !important;
	}
	.ui-slider-track {
		z-index:2;
	}
	.ui-slider-bg.ui-btn-active,
	.ui-flipswitch-active.ui-bar-inherit {
		background-color: #6dac20 !important;
		color:white !important;
	}
</style>


<form>
<div>
    <label for="flip-checkbox-1">Flip toggle switch checkbox:</label>
    <input type="checkbox" data-role="flipswitch" name="flip-checkbox-1" id="flip-checkbox-1">
</div>

<div>
 <label for="flip-checkbox-3">Flip toggle switch checkbox:</label>
    <input type="checkbox" data-role="flipswitch" name="flip-checkbox-3" id="flip-checkbox-3" data-on-text="Assured" data-off-text="Uncertain" data-wrapper-class="custom-size-flipswitch">
</div>

<div>
<select name="slider-flip-m" id="slider-flip-m" data-role="slider" data-mini="true">
    <option value="off">No</option>
    <option value="on" selected="">Yes</option>
</select>
</div>

<div>
<label for="slider-fill">Slider with fill and step of 50:</label>
<input type="range" name="slider-fill" id="slider-fill" value="60" min="0" max="1000" step="50" data-highlight="true">
</div>

<div data-role="rangeslider">
        <label for="range-1a">Rangeslider:</label>
        <input type="range" name="range-1a" id="range-1a" min="0" max="100" value="40">
        <label for="range-1b">Rangeslider:</label>
        <input type="range" name="range-1b" id="range-1b" min="0" max="100" value="80">
</div>

<div>
<fieldset data-role="controlgroup">
    <legend>Checkboxes, vertical controlgroup:</legend>
    <input type="checkbox" name="checkbox-1a" id="checkbox-1a" checked="">
    <label for="checkbox-1a">Cheetos</label>
    <input type="checkbox" name="checkbox-2a" id="checkbox-2a">
    <label for="checkbox-2a">Doritos</label>
</fieldset>

</div>
















</form>




 
<?php 
// Finally print the footer 
LBWeb::lbfooter();
?>