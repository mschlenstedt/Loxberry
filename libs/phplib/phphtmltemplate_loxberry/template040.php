<?php
// BEGIN DEBUG
################################################################################
# PHP-HTML::Template                                                           #
# http://phphtmltemplate.sourceforge.net/                                      #
################################################################################
# A template system for PHP based on HTML::Template Perl Module                #
# Version 0.4.0                                                                #
# 11-DEC-2017 MODIFIED FOR PHP7 and LOXBERRY                                   #
# See file README for details                                                  #
################################################################################
# Author: Juan R. Pozo, jrpozo@conclase.net                                    #
# License: GNU GPL (included in file "LICENSE")                                #
# (c) 2002 by Juan R. Pozo                                                     #
# http://html.conclase.net/                                                    #
# http://www.planhost.net/                                                     #
################################################################################
# HTML::Template Perl module copyright by Sam Tregar                           #
################################################################################
# Please consider making a donation today. Visit my amazon.com wishlist at:    #
# http://html.conclase.net/link/wishlist                                       #
# Thank you :)                                                                 #
################################################################################

/* ************** *
 * TEMPLATE CLASS *
 * ************** */
// END DEBUG

class Template {
    // The array of options
    var $options;

    // The tags that need a NAME attribute    
    var $need_names = array(
        "TMPL_VAR"     => 1,
        "TMPL_LOOP"    => 1,
        "TMPL_IF"      => 1,
        "TMPL_UNLESS"  => 1,
        "TMPL_INCLUDE" => 1
    );

    // Vars for Parse phase
    var $template     = NULL;    // the template file in memory
    var $nodes        = array(); // the linearized parse tree
    var $names        = array(); // the names of the variables that this template needs
    var $depth        = 0;       // the inclusion depth of this template

    // Vars for AddParam phase
    var $paramScope   = array(); // enclosing scopes of variable value as we add parameters    
    var $param        = NULL;    // the variables values assigned by the user

    // Vars for Output phase
    var $output       = NULL;    // the output string
    var $totalPass    = array(); // Stack for loops: total passes of current loop
    var $curPass      = array(); // Stack for loops: current pass of current loop

    var $version = "0.4.0";

    // The class constructor
    function Template($options)
    {
        // if the argument is a scalar, it is taken as the template file name
        // otherwise we take it as an associative array of option=>value pairs
        if (is_scalar($options)) {
            $filename = $options;
            unset($options);
            $options = array('filename' => $filename);
        } else if (!is_array($options)) {
            trigger_error("Template->Template() : Trying to create template without providing a template filename or an options array", E_USER_ERROR);
        }

        if (isset($options['_parent'])) {
            $this->nodes = $options['_parent']->nodes;
            $this->names = $options['_parent']->names;
            $this->depth =  $options['_parent']->depth + 1;
        }
        $this->SetOptions($options);

        // BEGIN DEBUG
        // We can start showing debug information from now on
        if (!isset($options['parent']) && $this->options['debug']) {
            echo("<h1>Template::New()</h1>\n");
            echo("<p>Debug mode on.</p>");
            echo("<p>Thanks for using PHP-HTML::Template.</p>");
            echo("<p>If you find any bugs, please report them to <a href='mailto:jrpozo@conclase.net'>jrpozo@conclase.net</a> along with an example and the version number of this library.</p>");
            echo("<p>Current version number is " . $this->version . "</p>");
        }
        // END DEBUG
        $filename = $this->options['filename'];
        if (!is_readable($filename)) {
            trigger_error("Template->Template() : Template file \"".$filename."\" not found", E_USER_ERROR);
        }
        // BEGIN DEBUG
        if ($this->options['debug']) {
            echo("<p>Opening file ".$filename."</p>");
        }
        // END DEBUG
        $f = fopen($filename, "r");
        $this->template = fread($f, filesize($filename));
        fclose($f);
        // BEGIN DEBUG
        if ($this->options['debug']) {
            echo("<p>File closed. ".filesize($filename)." bytes read into memory.</p>");
        }
        // END DEBUG
        if ($this->options['parse']) {
            // BEGIN DEBUG
            if (!isset($options['parent']) && $this->options['debug']) {
                echo("<p>Going to parse template now... good luck!</p>");
            }
            // END DEBUG
            $this->Parse();
            $this->defScope[] = $this->names;
            $this->paramScope[] = $this->param;
        }
    }

    // Fill in the $options array
    function SetOptions($options)
    {
        // We first set the default values for all options
        $this->options = array(
               "debug"             => 0,
               "die_on_bad_params" => 1,
               "strict"            => 1,
               "loop_context_vars" => 0,
               "max_includes"      => 10,
               "global_vars"       => 0,
               "no_includes"       => 0,
               "case_sensitive"    => 0,
               "hash_comments"     => 0,
               "parse"             => 1,
               "imark"             => '<',
               "emark"             => '>',
               "parse_html_comments"         => 1,
               "vanguard_compatibility_mode" => 0
               );

        // and then the values provided by the user override those values
        foreach ($options as $key => $value) {
            $this->options[strtolower($key)] = $value;
        }

        // vanguard compatibility mode enforces die_on_bad_params = 0
        if ($this->options["vanguard_compatibility_mode"]) {
            $this->options["die_on_bad_params"] = 0;
        }

        // initial and end tags cannot take the same value
        if ($this->options["imark"] == $this->options["emark"]) {
        //    trigger_error("Template::SetOptions() - Error, imark and emark options cannot take the same values", E_USER_ERROR);
        }
    }
    
    // This functions escapes regex metacharacters (outside square brackets)
    function EscapePREGText($text)
    {
        return strtr($text, array('\\'=>'\\\\', '/'=>'\/', '^'=>'\^', '$'=>'\$', '.'=>'\.', '['=>'\[', ']'=>'\]', '|'=>'\|', '('=>'\(', ')'=>'\)', '?'=>'\?', '*'=>'\*', '+'=>'\+', '{'=>'\{', '}'=>'\}', '%'=>'\%'));
    }

    function Parse()
    {
        // BEGIN DEBUG
        if ($this->options['debug']) {
            echo("<h1>Template::Parse()</h1>");
        }
        // END DEBUG

        $lineNumber = 1; // we reset in case the template is parsed succesive times

        // Stacks to keep track of where we are.

        // These contain the number of the corresponding initial node
        $inLoop   = array();
        $inIf     = array();
        $inUnless = array();

        // This contains the type of the last opened node type
        $curType  = array();
        
        // Handle the old vanguard format
        if ($this->options['vanguard_compatibility_mode']) {
            $expr = $this->options['imark']."TMPL_VAR NAME=\\1".$this->options['emark'];
            $this->template = preg_replace("/%([-\w\/\.+]+)%/", $expr, $this->template);
            // BEGIN DEBUG
            if ($this->options['debug']) {
                echo("Vanguard style tags converted to normal tags<br>\n");
            }
            // END DEBUG
        }

        // Strip hash comments (### comment)
        if ($this->options['hash_comments']) {
            $this->template = preg_replace("/### .*/", "", $this->template);
            // BEGIN DEBUG
            if ($this->options['debug']) {
                echo("Hash comments stripped<br>\n");
            }
            // END DEBUG
        }

        // Now split up the template
        // BEGIN DEBUG
        if ($this->options['debug']) {
            echo("Splitting up template in chunks<br>\n");
        }
        // END DEBUG

        // Two possible delimiters, depending on initial mark shape. Examples:
        // [[ => <!--\s*[[ and [[
        // <[ => <!--\s*[  and <[
        // <  => <!--\s* and <

        $imark  = $this->EscapePREGText($this->options['imark']);
        $emark  = $this->EscapePREGText($this->options['emark']);
        $emark0 = $this->EscapePREGText($this->options['emark'][0]);
        if ($this->options['parse_html_comments']) {
            if ($this->options['imark'][0] == '<') {
                $delim = "<(?:!--\\s*)?".substr($imark, 1);
            } else {
                $delim = "(?:<!--\\s*)?".$imark;
            }
            if ($this->options['emark'][0] == '>') {
                $delim2 = substr($emark, 0, strlen($emark)-1)."(?:\s*--)?>";
            } else {
                $delim2 = $emark."(?:\s*-->)?";
            }
        } else {
            $delim = $imark;
            $delim2 = $emark;
        }

        // One Regex to rule them all
        $regex = "/(" . $delim . "\/?[Tt][Mm][Pp][Ll]_\w+(?:(?:\s+(?:(?:\"[^\"]*\")|(?:\'[\']*\')|(?:[^=\s".$emark0."]+))(?:=(?:\"[^\"]*\"|\'[^\']*\'|(?:[^\s".$emark0."]*)))?)(?:\s+[^=\s]+(?:=(?:\"[^\"]+\"|\'[^\']\'|(?:[^\s".$emark0."]*)))?)*)?".$delim2.")(?m)/";
        // One Regex to find them
        $regex2 = "/" . $delim . "(\/?[Tt][Mm][Pp][Ll]_\w+)((?:\s+(?:(?:\"[^\"]*\")|(?:\'[\']*\')|(?:[^=\s".$emark0."]+))(?:=(?:\"[^\"]*\"|\'[^\']*\'|(?:[^\s".$emark0."]*)))?)(?:\s+[^=\s]+(?:=(?:\"[^\"]+\"|\'[^\']\'|(?:[^\s".$emark0."]*)))?)*)?".$delim2."(?m)/";

        // One Regex to bring them all and in the darkness bind them 
        // In the Land of Mordor where the Shadows lie.
        // Oh, never mind...
        $chunks = preg_split($regex, $this->template, -1, PREG_SPLIT_NO_EMPTY|PREG_SPLIT_DELIM_CAPTURE);

        // BEGIN DEBUG
        if ($this->options['debug']) {
            echo("Template splitted, ".count($chunks)." chunks obtained<br>\n");
            echo("<pre>");
            foreach($chunks as $k=>$v) {
                echo("<b>[$k]</b> ".htmlentities($v)."\n");
            }
            echo("</pre>");
        }
        // END DEBUG

        // All done with template
        unset ($this->template);
        
        // Loop through chunks, filling up the linearized parse tree
        for ($i = 0; $i < count($chunks); $i++) {
            if (preg_match($regex2, $chunks[$i], $tag)) {
                $which  = strtoupper($tag[1]);
                // This seems to be a template tag
                // BEGIN DEBUG
                if ($this->options['debug']) {
                    echo("<hr>Template tag found: <code>".htmlentities($which)."</code><br>\n");
                    echo("<pre>tag\n");
                    print_r($tag);
                    echo("</pre>");
                }
                // END DEBUG
                
                $var = array("name"=>NULL, "escape"=>NULL, "global"=>NULL, "default"=>NULL);
                if (isset($tag[2])) {
                    $token = preg_split("/((?:[^\s=]+=)?(?:(?:\"[^\"]+\")|(?:\'[^\']+\')|(?:\S*)))/", trim($tag[2]), -1, PREG_SPLIT_NO_EMPTY|PREG_SPLIT_DELIM_CAPTURE);
                    foreach($token as $tok) {
                        if (preg_match("/=/", $tok)) {
                            $t = preg_split("/\s*=\s*/", $tok, 3);
                            preg_match("/(?:\"([^\"]*)\")|(?:\'([^\']*)\')|(\S*)/", $t[1], $match);
                            $var[strtolower($t[0])] = max(isset($match[1])?$match[1]:"", isset($match[2])?$match[2]:"", isset($match[3])?$match[3]:"");
                        } else if (!preg_match("/^\s*$/", $tok)) {
                            preg_match("/(?:\"([^\"]*)\")|(?:\'([^\']*)\')|(\S*)/", $tok, $match);
                            $var["name"] = max(isset($match[1])?$match[1]:"", isset($match[2])?$match[2]:"", isset($match[3])?$match[3]:"");
                        }
                    }
                }
                $name    = $var["name"];
                $escape  = $var["escape"];
                $global  = $var["global"];
                $default = $var["default"];
                
                // BEGIN DEBUG
                if ($this->options['debug']) {
                    echo("<b>Found values:</b><br>\n");
                    echo("<code>name....: ".htmlentities($name)."</code><br>\n");
                    echo("<code>escape..: ".htmlentities($escape)."</code><br>\n");
                    echo("<code>global..: ".htmlentities($global)."</code><br>\n");
                    echo("<code>default.: ".htmlentities($default)."</code><br>\n");
                    echo("Normalizing...<br><br>\n");
                }
                // END DEBUG
                // ESCAPE
                if ($escape == "1") {
                    $escape = "HTML";
                } else if (empty($escape) || !strcmp($escape, "NONE")) {
                    $escape = 0;
                } else {
                    $escape = strtoupper($escape);
                }

                // GLOBAL
                $global = ($global) ? 1 : 0;

                // NAME
                // Allow mixed case in filenames, otherwise flatten
                if ($which != 'TMPL_INCLUDE' && !$this->options['case_sensitive']) {
                    $name = strtolower($name);
                }

                // BEGIN DEBUG
                if ($this->options['debug']) {
                    echo("<b>Final values:</b><br>\n");
                    echo("<code><b>Which...:</b> ".$which."</code><br>\n");
                    echo("<code><b>Name....:</b> ".$name."</code><br>\n");
                    echo("<code><b>Escape..:</b> ".$escape."</code><br>\n");
                    echo("<code><b>Global..:</b> ".$global."</code><br>\n");
                    echo("<code><b>Default.:</b> ".$default."</code><br><br>\n");
                }
                // END DEBUG

                // Die if name contains invalid characters
                if (!preg_match("/^[-\w\/+_\.]*$/", $name)) {
                    trigger_error("Template::Parse() : Invalid character(s) in NAME attribute (".htmlentities($name).") for ".$which." tag, found at ".$this->options['filename'].", line ".$lineNumber, E_USER_ERROR);
                }

                // Die if we need a name and didn't get one
                if (empty($name) && isset($this->need_names[$which])) {
                    trigger_error("Template::Parse() : No NAME given to a ".$which." tag at ".$this->options['filename']." : line ".$lineNumber, E_USER_ERROR);
                }

                // Die if we got an escape but can't use one
                if ($escape and ($which != 'TMPL_VAR')) {
                    trigger_error("Template::Parse() : ESCAPE option invalid in a ".$which." tag at ".$this->options['filename']." : line ".$lineNumber, E_USER_ERROR);
                }
                
                // Die if we got a default but can't use one
                if ($default and ($which != 'TMPL_VAR')) {
                    trigger_error("Template::Parse() : DEFAULT option invalid in a ".$which." tag at ".$this->options['filename']." : line ".$lineNumber, E_USER_ERROR);
                }

                // Wow, it doesn't die!

                // Take actions depending on which tag found
                switch ($which) { // ...said the witch

                case 'TMPL_VAR':
                    // BEGIN DEBUG
                    if ($this->options['debug']) {
                        echo("Adding VAR node<br>\n");
                    }
                    // END DEBUG
                    if (in_array($name, array('__pass__', '__passtotal__', '__counter__'))) {
                        if (count($inLoop)) {
                            $this->nodes[] = new Node("ContextVAR", $name);
                        } else {
                            trigger_error("Template::Parse() : Found context VAR tag outside of LOOP, at ".$this->options['filename']." : line ".$lineNumber, E_USER_ERROR);
                        }
                    } else {
                        $this->nodes[] = new Node("VAR", $name, $escape, $global, $default);
                        $this->names[$name] = 1;
                    }
                    // BEGIN DEBUG
                    if ($this->options['debug']) {
                        echo("VAR Node added.<br>\n");
                        $this->ListNodes();
                    }
                    // END DEBUG
                    break;

                case 'TMPL_LOOP':
                    // BEGIN DEBUG
                    if ($this->options['debug']) {
                        echo("Adding LOOP node<br>\n");
                    }
                    // END DEBUG
                    $this->nodes[] = new Node("LOOP", $name, NULL, $global);
                    $inLoop[] = count($this->nodes)-1;
                    $curType[] = "LOOP";
                    $this->names[$name] = 1;
                    // BEGIN DEBUG
                    if ($this->options['debug']) {
                        echo("LOOP node added<br>\n");
                        $this->ListNodes();
                    }
                    // END DEBUG
                    break;

                case '/TMPL_LOOP':
                    if (!strcmp(end($curType), "LOOP")) {
                        // BEGIN DEBUG
                        if ($this->options['debug']) {
                            echo("Ending LOOP ".end($inLoop)."<br>\n");
                        }
                        // END DEBUG
                        $this->nodes[end($inLoop)]->jumpTo = count($this->nodes);
                        array_pop($inLoop);
                        array_pop($curType);
                        // BEGIN DEBUG
                        if ($this->options['debug']) {
                            echo("LOOP ended<br>\n");
                            $this->ListNodes();
                        }
                        // END DEBUG
                    } else {
                        trigger_error("Template::Parse() : Nesting error: found end /TMPL_LOOP tag without its corresponding initial tag, at ".$this->options['filename']." : line ".$lineNumber." (last opened tag is of type \"".end($curType)."\")", E_USER_ERROR);
                    }
                    break;

                case 'TMPL_IF':
                    // BEGIN DEBUG
                    if ($this->options['debug']) {
                        echo("Adding IF node<br>\n");
                    }
                    // END DEBUG
                    if (in_array($name, array('__first__', '__odd__', '__inner__', '__last__'))) {
                        if (count($inLoop)) {
                            $this->nodes[] = new Node("ContextIF", $name);
                        } else {
                            trigger_error("Template::Parse() : Found context IF/UNLESS tag outside of LOOP, at ".$this->options['filename']." : line ".$lineNumber, E_USER_ERROR);
                        }
                    } else {
                        $this->nodes[] = new Node("IF", $name, NULL, $global);
                        $this->names[$name] = 1;
                    }
                    $inIf[] = count($this->nodes)-1;
                    $curType[] = "IF";
                    // BEGIN DEBUG
                    if ($this->options['debug']) {
                        echo("IF node added<br>\n");
                        $this->ListNodes();
                    }
                    // END DEBUG
                    break;

                case '/TMPL_IF':
                    if (!strcmp(end($curType), "IF")) {
                        // BEGIN DEBUG
                        if ($this->options['debug']) {
                            echo("Ending IF<br>\n");
                        }
                        // END DEBUG
                        $this->nodes[end($inIf)]->jumpTo = count($this->nodes);
                        array_pop($inIf);
                        array_pop($curType);
                        // BEGIN DEBUG
                        if ($this->options['debug']) {
                            echo("IF ended<br>\n");
                            $this->ListNodes();
                        }
                        // END DEBUG
                    } else {
                        trigger_error("Template::Parse() : Nesting error: found end /TMPL_IF tag without its corresponding initial tag, at ".$this->options['filename']." : line ".$lineNumber, E_USER_ERROR);
                    }
                    break;

                case 'TMPL_UNLESS':
                    // BEGIN DEBUG
                    if ($this->options['debug']) {
                        echo("Adding UNLESS node<br>\n");
                    }
                    // END DEBUG
                    if (in_array($name, array('__first__', '__odd__', '__inner__', '__last__'))) {
                        $this->nodes[] = new Node("ContextUNLESS", $name);
                    } else {
                        $this->nodes[] = new Node("UNLESS", $name, NULL, $global);
                        $this->names[$name] = 1;
                    }
                    $inUnless[] = count($this->nodes)-1;
                    $curType[] = "UNLESS";
                    // BEGIN DEBUG
                    if ($this->options['debug']) {
                        echo("UNLESS node added<br>\n");
                        $this->ListNodes();
                    }
                    // END DEBUG
                    break;

                case '/TMPL_UNLESS':
                    if (!strcmp(end($curType), "UNLESS")) {
                        // BEGIN DEBUG
                        if ($this->options['debug']) {
                            echo("Ending UNLESS<br>\n");
                        }
                        // END DEBUG
                        $this->nodes[end($inUnless)]->jumpTo = count($this->nodes);
                        array_pop($inUnless);
                        array_pop($curType);
                        // BEGIN DEBUG
                        if ($this->options['debug']) {
                            echo("UNLESS ended<br>\n");
                            $this->ListNodes();
                        }
                        // END DEBUG
                    } else {
                        trigger_error("Template::Parse() : Nesting error: found end /TMPL_UNLESS tag without its corresponding initial tag, at ".$this->options['filename']." : line ".$lineNumber, E_USER_ERROR);
                    }
                    break;

                case 'TMPL_ELSE':
                    if (!strcmp(end($curType), "IF") || !strcmp(end($curType), "UNLESS")) {
                        // BEGIN DEBUG
                        if ($this->options['debug']) {
                            echo("Starting ELSE<br>\n");
                        }
                        // END DEBUG
                        if (!strcmp(end($curType), "IF")) {
                            $this->nodes[end($inIf)]->else = count($this->nodes);
                        } else {
                            $this->nodes[end($inUnless)]->else = count($this->nodes);
                        }
                        // BEGIN DEBUG
                        if ($this->options['debug']) {
                            echo("ELSE started<br>\n");
                            $this->ListNodes();
                        }
                        // END DEBUG
                    } else {
                        trigger_error("Template::Parse() : Nesting error: found end TMPL_ELSE tag without its corresponding initial tag, at ".$this->options['filename']." : line ".$lineNumber, E_USER_ERROR);
                    }
                    break;

                case 'TMPL_INCLUDE':
                    if (!$this->options['no_includes'])
                    {
                        if ($this->depth >= $this->options['max_includes'] && $this->options['max_includes'] > 0) {
                            trigger_error("Template::Parse() : Include error: Too many included templates, found at ".$this->options['filename']." : line ".$lineNumber, E_USER_ERROR);
                        } else {
                            // BEGIN DEBUG
                            if ($this->options['debug']) {
                                echo("Including template ".$name."<br>\n");
                            }
                            // END DEBUG
                            $newOptions = $this->options;
                            $newOptions['filename'] = $name;
                            $newOptions['_parent'] = $this;
                            new Template($newOptions);
                            // BEGIN DEBUG
                            if ($this->options['debug']) {
                                echo("<hr>Template included, returning to previous template<hr>\n");
                                $this->ListNodes();
                            }
                            // END DEBUG
                        }
                    }
                    break;

                default:    
                    trigger_error("Template::Parse() : Unknown or unmatched TMPL construct at ".$this->options['filename']." : line ".$lineNumber, E_USER_ERROR);
                    break;
                }
            } else {
                // This is not a template tag. If it is not a delimiter, skip until next delimiter
                // and add all trailing chunks as a new markup node
                // BEGIN DEBUG
                if ($this->options['debug']) {
                    echo("<hr>Markup node found<br>\n");
                }
                // END DEBUG
                // Make sure we didn't reject something TMPL_* but badly formed
                if ($this->options['strict'] && preg_match("/".$delim."\/?[Tt][Mm][Pp][Ll]_/", $chunks[$i])) {
                    trigger_error("Template::Parse() : Syntax error in &lt;TMPL_*&gt; tag at " . $this->options['filename'] . " : line " . $lineNumber, E_USER_ERROR);
                }
                $this->nodes[] = new Node("MARKUP", $chunks[$i]);
                // BEGIN DEBUG
                if ($this->options['debug']) {
                    $this->ListNodes();
                }
                // END DEBUG
            }
            // Count newlines in chunk and advance line count
            $lineNumber += substr_count($chunks[$i], "\n");
        }
        // Check if there's some unfinished block
        if (count($curType)) {
            trigger_error("Template::Parse() : Template ".$this->options['filename']." incorrectly terminated. Found ".end($curType)." tag without corresponding end tag", E_USER_ERROR);
        }
    }
    
    function ListNodes()
    {
        echo("<b>Contents of linearized parse tree</b><br>");
        for ($i=0; $i<count($this->nodes); $i++) {
            echo("<b>[".$i."]</b> - ".$this->nodes[$i]->type." - <code>".htmlentities(addcslashes($this->nodes[$i]->name, "\n\r"))."</code>".(($this->nodes[$i]->else===NULL)?"":" <code>{ Next } else { ".$this->nodes[$i]->else." }</code>").(($this->nodes[$i]->jumpTo===NULL)?"":" - Jump to ".$this->nodes[$i]->jumpTo)."<br>\n");
        }
        echo("<b>Variables used in template</b><br>");
        ob_start();
        print_r($this->names);
        $b = ob_get_contents(); 
        ob_end_clean(); 
        echo("<pre>$b</pre>");
    }
    
    function AddParam($arg, $value=NULL)
    {
        // BEGIN DEBUG
        if ($this->options['debug']) {
            echo("<h1>Template::AddParam()</h1>");
        }
        // END DEBUG

        // We can call this with a two arguments (name value pair),
        // or one argument (an associative array) (see README for details).
        // If there are two arguments, the first must be a string, the second may a scalar or an array
        // if the second argument is an array, it must be an array of associative arrays for a loop node
        // If there's one argument, it must be an array, and its elements are name-value pairs.
        
        if (func_num_args() == 2) {
            if (is_scalar($value) || empty($value)) {
                // BEGIN DEBUG
                if ($this->options['debug']) {
                    echo("<p>Attempting to set scalar value \"".htmlentities($value)."\" for variable \"$arg\".</p>");
                }
                // END DEBUG
                if (!$this->options['case_sensitive']) {
                    $arg = strtolower($arg);
                    // BEGIN DEBUG
                    if ($this->options['debug']) {
                        echo("<p>case_sensitive option is off. Converting variable name to lowercase (\"$arg\").</p>");
                    }
                    // END DEBUG
                }
                if (isset($this->names[$arg])) {
                    $this->paramScope[count($this->paramScope)-1][$arg] = $value;
                    // BEGIN DEBUG
                    if ($this->options['debug']) {
                        echo("<p>Value set: \"$arg\" = \"".htmlentities($value)."\".</p>");
                    }
                    // END DEBUG
                } else if ($this->options['die_on_bad_params']) {
                    trigger_error("Template::AddParam() : Attempt to set value for non existent variable name '".$arg."' - this variable name doesn't match any declarations in the template file", E_USER_ERROR);
                }
            } else if (is_array($value)) {
                // BEGIN DEBUG
                if ($this->options['debug']) {
                    echo("<p>Attempting to set array value for variable \"$arg\".</p>");
                }
                // END DEBUG
                if (!$this->options['case_sensitive']) {
                    $arg = strtolower($arg);
                    // BEGIN DEBUG
                    if ($this->options['debug']) {
                        echo("<p>case_sensitive option is off. Converting variable name to lowercase (\"$arg\").</p>");
                    }
                    // END DEBUG
                }
                if (isset($this->names[$arg])) {
                    // BEGIN DEBUG
                    if ($this->options['debug']) {
                        echo("<p>The variable \"$arg\" exists in the template.</p>");
                    }
                    // END DEBUG
                    $this->paramScope[count($this->paramScope)-1][$arg] = array();
                    $this->paramScope[] = $this->paramScope[count($this->paramScope)-1][$arg];
                    foreach($value as $a) {
                        if (!is_array($a)) {
                            // error
                            trigger_error("Template::AddParam() : Must use arrays of associative arrays for loop parameters", E_USER_ERROR);
                        } else {
                            $this->paramScope[count($this->paramScope)-1][] = array();
                            $this->paramScope[] = $this->paramScope[count($this->paramScope)-1][count($this->paramScope[count($this->paramScope)-1])-1];
                            // BEGIN DEBUG
                            if ($this->options['debug']) {
                                echo("<p>Adding variables inside loop...</p><blockquote>");
                            }
                            // END DEBUG
                            foreach ($a as $k=>$v) {
                                if (is_scalar($v)) {
                                    $this->SetValue($k, $v);
                                } else {
                                    $this->AddParam($k, $v);
                                }
                            }
                            // BEGIN DEBUG
                            if ($this->options['debug']) {
                                echo("</blockquote>");
                            }
                            // END DEBUG
                            array_pop($this->paramScope);
                        }
                    }
                    array_pop($this->paramScope);
                } else if ($this->options['die_on_bad_params']) {
                    trigger_error("Template::AddParam() : Attempt to set value for non existent variable name '".$arg."' - this variable name doesn't match any declarations in the template file", E_USER_ERROR);
                }
            } else {
                // error
                trigger_error("Template::AddParam() : Wrong value type", E_USER_ERROR);
            }
        } else if (func_num_args() == 1) {
            if (is_array($arg)) {
                foreach ($arg as $k => $v) {
                    $this->AddParam($k, $v);
                }
            } else {
                // error
                trigger_error("Template::AddParam() : Only one argument set, but it's not an array", E_USER_ERROR);
            }
        } else {
            // error
            trigger_error("Template::AddParam() : Wrong argument count (".func_num_args().") arguments", E_USER_ERROR);
        }
    }
    
    function SetValue($arg, $value)
    {
        // Like AddParam but exclusively for setting scalar values
        if (is_scalar($value) || empty($value)) {
            // BEGIN DEBUG
            if ($this->options['debug']) {
                echo("<p>Attempting to set scalar value \"".htmlentities($value)."\" for variable \"$arg\".</p>");
            }
            // END DEBUG
            if (!$this->options['case_sensitive']) {
                // BEGIN DEBUG
                if ($this->options['debug']) {
                    echo("<p>case_sensitive option is off. Converting variable name to lowercase (\"$arg\").</p>");
                }
                // END DEBUG
                $arg = strtolower($arg);
            }
            if (isset($this->names[$arg])) {
                $this->paramScope[count($this->paramScope)-1][$arg] = $value;
                // BEGIN DEBUG
                if ($this->options['debug']) {
                    echo("<p>Value set: \"$arg\" = \"".htmlentities($value)."\".</p>");
                }
                // END DEBUG
            } else if ($this->options['die_on_bad_params']) {
                trigger_error("Template::SetValue() : Attempt to set value for non existent variable name '".$arg."' - this variable name doesn't match any declarations in the template file", E_USER_ERROR);
            }
        } else{
            // error
            trigger_error("Template::SetValue() : Value must be a scalar", E_USER_ERROR);
        }
    }
    
    function Output()
    {
        // BEGIN DEBUG
        if ($this->options['debug']) {
            echo("<h1>Template::Output()</h1>");
        }
        // END DEBUG
        if (!isset($this->output)) {
            $this->paramScope = array();
            $this->paramScope[] = $this->param;
            $this->totalPass = array();
            $this->curPass = array();

            // BEGIN DEBUG
            if ($this->options['debug']) {
                echo("Initial variable scope is:<pre>\n");
                print_r($this->paramScope[0]);
                echo("</pre>");
            }
            // END DEBUG

            $n = 0;
            while (isset($this->nodes[$n])) {
                $n = $this->ProcessNode($n);
            };
        }
        return $this->output;
    }
    
    function ProcessNode($n)
    {
        // BEGIN DEBUG
        if ($this->options['debug']) {
            echo("Processing node $n of type ".$this->nodes[$n]->type." <code>[".htmlentities($this->nodes[$n]->name)."]</code><br>\n");
        }
        // END DEBUG

        $node = $this->nodes[$n];
        switch ($node->type) {
        case "MARKUP":
            $this->output .= $node->name;
            return $n+1;
                
        case "VAR":
            if (isset($this->{paramScope[count($this->paramScope)-1][$node->name]})) {
                if (is_scalar($this->{paramScope[count($this->paramScope)-1][$node->name]})) {
                    $value = $this->{paramScope[count($this->paramScope)-1][$node->name]};
                } else if (is_array($this->{paramScope[count($this->paramScope)-1][$node->name]})) {
                    $value = count($this->{paramScope[count($this->paramScope)-1][$node->name]});
                }
                // BEGIN DEBUG
                else if ($this->options['debug']) {
                    echo("Variable <code>".$node->name."</code> is defined in current scope with empty value.<br>\n");
                }
                // END DEBUG
                // BEGIN DEBUG
                if ($this->options['debug']) {
                    echo("Variable <code>".$node->name."</code> is defined in current scope with value <code>".htmlentities($value)."</code>.<br>\n");
                }
                // END DEBUG
                if (!strcmp($node->escape, "HTML")) {
                    $this->output .= htmlspecialchars($value);
                } else if (!strcmp($node->escape, "URL")) {
                    $this->output .= htmlentities(urlencode($value));
                } else {
                    $this->output .= $value;
                }
            } else if ($node->default !== NULL) {
                // BEGIN DEBUG
                if ($this->options['debug']) {
                    echo("Variable <code>".$node->name."</code> is not defined in current scope but has a default value: <code>".htmlentities($node->default)."</code>.<br>\n");
                }
                // END DEBUG
                if (!strcmp($node->escape, "HTML")) {
                    $this->output .= htmlspecialchars($node->default);
                } else if (!strcmp($node->escape, "URL")) {
                    $this->output .= htmlentities(urlencode($node->default));
                } else {
                    $this->output .= $node->default;
                }
            } else if ($this->options['global_vars'] || $this->nodes[$n]->global) {
                // BEGIN DEBUG
                if ($this->options['debug']) {
                    echo("Variable <code>".$node->name."</code> is not defined in current scope, searching in enclosing scopes.<br>\n");
                }
                // END DEBUG
                for ($lvl = count($this->paramScope)-2; !isset($this->paramScope[$lvl][$node->name]) && $lvl>=0; $lvl--);
                if ($lvl>=0) {
                    if (is_scalar($this->paramScope[$lvl][$node->name])) {
                        $value = $this->paramScope[$lvl][$node->name];
                    } else if (is_array($this->paramScope[$lvl][$node->name])) {
                        $value = count($this->paramScope[$lvl][$node->name]);
                    }
                    // BEGIN DEBUG
                    else if ($this->options['debug']) {
                        echo("Variable <code>".$node->name."</code> is defined with empty value.<br>\n");
                    }
                    // END DEBUG
                    // BEGIN DEBUG
                    if ($this->options['debug']) {
                        echo("Found variable in scope depth $lvl with value <code>".htmlentities($value)."</code><br>\n");
                    }
                    // END DEBUG
                    if (!strcmp($node->escape, "HTML")) {
                        $this->output .= htmlentities($value);
                    } else if (!strcmp($node->escape, "URL")) {
                        $this->output .= htmlentities(urlencode($value));
                    } else {
                        $this->output .= $value;
                    }
                }
                // BEGIN DEBUG
                else if ($this->options['debug']) {
                    echo("Variable not found<br>\n");
                }
                // END DEBUG
            }
            // BEGIN DEBUG
            else if ($this->options['debug']) {
                echo("Variable not found or it is empty/NULL<br>\n");
            }
            // END DEBUG
            return $n+1;

        case "ContextVAR":
            if ($this->options['loop_context_vars'] && count($this->totalPass)) {
                // BEGIN DEBUG
                if ($this->options['debug']) {
                    echo("Variable <code>".$node->name."</code> is defined in current scope.<br>\n");
                }
                // END DEBUG
                switch ($node->name) {
                case "__pass__":
                case "__counter__":
                    $this->output .= $this->curPass[count($this->curPass)-1];
                    break;
                case "__passtotal__":
                    $this->output .= $this->totalPass[count($this->totalPass)-1];
                    break;
                }
            }
            return $n+1;

        case "LOOP":
            if (isset($this->paramScope[count($this->paramScope)-1][$node->name])) {
                // BEGIN DEBUG
                if ($this->options['debug']) {
                    echo("Variable <code>".$node->name."</code> is defined in current scope.<br>\n");
                }
                // END DEBUG
                if (!is_array($this->paramScope[count($this->paramScope)-1][$node->name])) {
                    trigger_error("Template->Output() : A scalar value was assigned to a LOOP var (".$node->name."), but LOOP vars only accept arrays of associative arrays as values,", E_USER_ERROR);
                }
                $this->paramScope[] = $this->paramScope[count($this->paramScope)-1][$node->name];
                $this->totalPass[] = count($this->paramScope[count($this->paramScope)-1]);
                $this->curPass[] = 0;
                // BEGIN DEBUG
                if ($this->options['debug']) {
                    echo("Entering loop. New variable scope is:<pre>\n");
                    print_r($this->paramScope[count($this->paramScope)-1]);
                    echo("</pre>");
                    echo("Loop will be traversed ".count($this->paramScope[count($this->paramScope)-1])." times<hr>\n");
                }
                // END DEBUG
                for ($i=0; $i<$this->totalPass[count($this->totalPass)-1]; $i++) {
                    $this->curPass[count($this->curPass)-1]++;
                    $this->paramScope[] = $this->paramScope[count($this->paramScope)-1][$i];
                    // BEGIN DEBUG
                    if ($this->options['debug']) {
                        echo("Variable scope for this pass:<pre>\n");
                        print_r($this->paramScope[count($this->paramScope)-1]);
                        echo("</pre>");
                        echo("</pre>Traversing from node ".($n+1)." to node ".($node->jumpTo-1)."<hr>\n");
                    }
                    // END DEBUG
                    for($j=$n+1; $j<$node->jumpTo;) {
                        $j = $this->ProcessNode($j);
                    }
                    array_pop($this->paramScope);
                }
                array_pop($this->curPass);
                array_pop($this->totalPass);
                array_pop($this->paramScope);
                return $node->jumpTo;
            } else if ($this->options['global_vars'] || $this->nodes[$n]->global) {
                // BEGIN DEBUG
                if ($this->options['debug']) {
                    echo("Variable <code>".$node->name."</code> is not defined in current scope, searching in enclosing scopes.<br>\n");
                }
                // END DEBUG
                for ($lvl = count($this->paramScope)-2; !isset($this->paramScope[$lvl][$node->name]) && $lvl>=0; $lvl--);
                if ($lvl>=0) {
                    // BEGIN DEBUG
                    if ($this->options['debug']) {
                        echo("Found variable in scope depth $lvl<br>\n");
                    }
                    // END DEBUG
                    if (!is_array($this->paramScope[$lvl][$node->name])) {
                        trigger_error("Template->Output() : A LOOP var (".$node->name.") was trying to use a scalar value, but LOOP vars only accept arrays of associative arrays as values,", E_USER_ERROR);
                    }
                    $this->paramScope[] = $this->paramScope[$lvl][$node->name];
                    $this->totalPass[] = count($this->paramScope[count($this->paramScope)-1]);
                    $this->curPass[] = 0;
                    // BEGIN DEBUG
                    if ($this->options['debug']) {
                        echo("Entering loop. New variable scope is:<pre>\n");
                        print_r($this->paramScope[count($this->paramScope)-1]);
                        echo("</pre>");
                        echo("Loop will be traversed ".count($this->paramScope[count($this->paramScope)-1])." times<hr>\n");
                    }
                    // END DEBUG
                    for ($i=0; $i<$this->totalPass[count($this->totalPass)-1]; $i++) {
                        $this->curPass[count($this->curPass)-1]++;
                        $this->paramScope[] = $this->paramScope[count($this->paramScope)-1][$i];
                        // BEGIN DEBUG
                        if ($this->options['debug']) {
                            echo("Variable scope for this pass:<pre>\n");
                            print_r($this->paramScope[count($this->paramScope)-1]);
                            echo("</pre>");
                            echo("</pre>Traversing from node ".($n+1)." to node ".($node->jumpTo-1)."<hr>\n");
                        }
                        // END DEBUG
                        for($j=$n+1; $j<$node->jumpTo;) {
                            $j = $this->ProcessNode($j);
                        }
                        array_pop($this->paramScope);
                    }
                    array_pop($this->curPass);
                    array_pop($this->totalPass);
                    array_pop($this->paramScope);
                    return $node->jumpTo;
                }
                // BEGIN DEBUG
                else if ($this->options['debug']) {
                    echo("Variable not found<br>\n");
                }
                // END DEBUG
            }

        case "IF":
        case "UNLESS":
            $cond = 0; // by default, condition is false
            // BEGIN DEBUG
            if ($this->options['debug']) {
                echo("Entering IF/UNLESS branch<br>\n");
            }
            // END DEBUG
            $else = $node->else;
            if (isset($this->paramScope[count($this->paramScope)-1][$node->name])) {
                // BEGIN DEBUG
                if ($this->options['debug']) {
                    echo("Variable <code>".$node->name."</code> is defined in current scope.<br>\n");
                }
                // END DEBUG
                if (is_scalar($this->paramScope[count($this->paramScope)-1][$node->name])) {
                    $cond = $this->paramScope[count($this->paramScope)-1][$node->name];
                } else if (is_array($this->paramScope[count($this->paramScope)-1][$node->name])) {
                    $cond = count($this->paramScope[count($this->paramScope)-1][$node->name]);
                }
                // BEGIN DEBUG
                if ($this->options['debug']) {
                    echo("Variable found, value is <code>$cond</code>, condition is ".($cond!=false)."<br>\n");
                }
                // END DEBUG
            } else if ($this->options['global_vars'] || $this->nodes[$n]->global) {
                // BEGIN DEBUG
                if ($this->options['debug']) {
                    echo("Variable <code>".$node->name."</code> is not defined in current scope, searching in enclosing scopes.<br>\n");
                }
                // END DEBUG
                for ($lvl = count($this->paramScope)-2; !isset($this->paramScope[$lvl][$node->name]) && $lvl>=0; $lvl--);
                if ($lvl>=0) {
                    // BEGIN DEBUG
                    if ($this->options['debug']) {
                        echo("Found variable in scope depth $lvl<br>\n");
                    }
                    // END DEBUG
                    if (is_scalar($this->paramScope[$lvl][$node->name])) {
                        $cond = $this->paramScope[$lvl][$node->name];
                    } else if (is_array($this->paramScope[$lvl][$node->name])) {
                        $cond = count($this->paramScope[$lvl][$node->name]);
                    } else { // empty var
                        $cond = 0;
                    }
                    // BEGIN DEBUG
                    if ($this->options['debug']) {
                        echo("Variable found, value is <code>$cond</code>, condition is ".($cond!=false)."<br>\n");
                    }
                    // END DEBUG
                } else {
                    $cond = 0;
                    // BEGIN DEBUG
                    if ($this->options['debug']) {
                        echo("Variable not found, condition is false<br>\n");
                    }
                    // END DEBUG
                }
            } else {
                $cond = 0;
                // BEGIN DEBUG
                if ($this->options['debug']) {
                    echo("Variable not found, condition is false<br>\n");
                }
                // END DEBUG
            }
            if (!strcmp($node->type, "UNLESS")) {
                $cond = !$cond;
            }
            if ($cond) {
                $last = ($else)?$else:$node->jumpTo;
                // BEGIN DEBUG
                if ($this->options['debug']) {
                    echo("Condition is true, traversing nodes ".($n+1)." to ".($last-1)."<br>\n");
                }
                // END DEBUG
                for ($j = $n+1; $j < $last;) {
                    $j = $this->processNode($j);
                }
            } else if ($else) {
                // BEGIN DEBUG
                if ($this->options['debug']) {
                    echo("Condition is false, traversing nodes ".$else." to ".($node->jumpTo-1)."<br>\n");
                }
                // END DEBUG
                for ($j = $else; $j < $node->jumpTo;) {
                    $j = $this->processNode($j);
                }
            }
            return $node->jumpTo;
            
        case "ContextIF":
        case "ContextUNLESS":
            if ($this->options['loop_context_vars']) {
                // BEGIN DEBUG
                if ($this->options['debug']) {
                    echo("Entering ContextIF/ContextUNLESS branch<br>\n");
                }
                // END DEBUG
                $else = $node->else;
                $cond = 0;
                switch ($node->name) {
                case "__first__":
                    if ($this->curPass[count($this->curPass)-1] == 1) {
                        $cond = 1;
                    }
                    break;
                case "__odd__":
                    if ($this->curPass[count($this->curPass)-1] % 2) {
                        $cond = 1;
                    }
                    break;
                case "__inner__":
                    if ($this->curPass[count($this->curPass)-1] > 1 && $this->curPass[count($this->curPass)-1] < $this->totalPass[count($this->totalPass)-1]) {
                        $cond = 1;
                    }
                    break;
                case "__last__":
                    if ($this->curPass[count($this->curPass)-1] == $this->totalPass[count($this->totalPass)-1]) {
                        $cond = 1;
                    }
                    break;
                }
                if (!strcmp($node->type, "ContextUNLESS")) {
                    $cond = !$cond;
                }
                if ($cond) {
                    $last = ($else) ? $else : $node->jumpTo;
                    // BEGIN DEBUG
                    if ($this->options['debug']) {
                        echo("Condition is true, traversing nodes ".($n+1)." to ".($last-1)."<br>\n");
                    }
                    // END DEBUG
                    for ($j = $n+1; $j < $last;) {
                        $j = $this->processNode($j);
                    }
                } else if ($else) {
                    // BEGIN DEBUG
                    if ($this->options['debug']) {
                        echo("Condition is false, traversing nodes ".$else." to ".($node->jumpTo-1)."<br>\n");
                    }
                    // END DEBUG
                    for ($j = $else; $j < $node->jumpTo;) {
                        $j = $this->processNode($j);
                    }
                }
                return $node->jumpTo;
            }
        }
    }
    
    function EchoOutput()
    {
        $this->Output();
        echo($this->output);
    }
    
    // ResetParams() and ResetOutput() can be useful when processing the same template with new
    // variable values, without repeating the Parse phase.

    function ResetParams()
    {
        $this->param = array();
    }

    function ResetOutput()
    {
        $this->output = NULL;
    }
    
    function SaveCompiled($outputdir = NULL, $overwrite = 0) {
        if ($outputdir === NULL) {
            $outputdir = dirname($this->options['filename']);
        }
        if (!is_writable($outputdir)) {
            trigger_error("Template::SaveCompiled() - Output directory not writable", E_USER_ERROR);
        } else {
            $file = basename($this->options['filename']);
            $output = $outputdir . "/" . $file . "c";
            if (file_exists($output) && !$overwrite) {
                trigger_error("Template::SaveCompiled() - File " . $output . " already exists, cannot write compiled template", E_USER_ERROR);
            } else {
                $f = fopen($output, "w");
                fwrite($f, serialize($this));
                fclose($f);
                return realpath($output);
            }
        }
        return NULL; // should never arrive here anyway...
    }
}

class Node
{
    var $type    = NULL; // Current types: MARKUP, VAR, IF/ContextIF, UNLESS/ContextUNLESS, LOOP
    var $name    = NULL; // Variable name, or markup value
    var $escape  = NULL; // Current types: HTML, URL or NULL
    var $global  = NULL; // Set to 1 if GLOBAL attribute is set for this node, NULL otherwise
    var $default = NULL; // Default value
    var $jumpTo  = NULL;
    var $else    = NULL;
    
    function Node($type, $name, $global=NULL, $escape=NULL, $default=NULL)
    {
        $this->type    = $type;
        $this->name    = $name;
        $this->global  = $global;
        $this->escape  = $escape;
        $this->default = $default;
    }
}

function &LoadCompiledTemplate($filename) {
    if (!is_readable($filename)) {
        trigger_error("LoadCompiledTemplate() - Cannot read file " . $filename, E_USER_ERROR);
    } else {
        $f = fopen($filename, "r");
        $data = fread($f, filesize($filename));
        fclose($f);
        return unserialize($data);
    }
}
