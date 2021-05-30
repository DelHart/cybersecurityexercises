var load_time;
var countdown;
var events = {};
var player_id;
var company = { assets : {}, sfns : {}, threats : [] };
var player = { skills : { }, actions : {} };
var recent_messages = [];
var empty_action = { 'id' : 0, 'name' : "wait", 'time' : 0, 'difficulty' : 'hard', 'cost' : 0, 'description' : "new actions will become available over time"};

function init (id) {
    load_time = new Date().getTime();
    player_id = id;

    addMessage("Welcome Player" + player_id);
    $.get ("/ww/" + player_id + "/setup", setup);
//    scheduleEvent (5, {'action' : 'msg', 'data' : '5 seconds have passed'});
//    scheduleEvent (10, {'action' : 'msg', 'data' : '3 seconds have passed'});
    updateTime ();


} // init

function updateTime () {
    var new_time = new Date().getTime() - load_time;
    var secs = Math.round (new_time / 1000);
    $("#clock").text (secs);
    countdown = countdown - 1;
    if (countdown > 0) {
        $("#countdown").text (countdown);
    }
    processEvents (secs);
    setTimeout (function() {updateTime();}, 1000);
} // updateTime

function processEvents (s) {
    var e = events[s];
    if (e != null) {
        e.forEach ( function (item, index, array) {
            if (item['action'] == 'msg' ) {
                addMessage (item['data']);
            }
        })
        updateCompany();
        updatePlayer();
    }


} // processEvents

function scheduleEvent (time, e) {

    if (events[time] == null) {
        events[time] = [];
    }
    events[time].push (e);

} // scheduleEvent

function updateCompany () {
   //$("#c_name").text ("blah");
   
    var assets = Object.keys (company.assets);
    assets.forEach (function (item, index, array) {
        var a = company.assets[item];
        var ival = "#asset_value_" + a.name;
        $(ival).text (a.value);

        var fields = Object.keys (company.sfns);
        fields.forEach (function (item2, index2, array2) {
            var j = '#asset_' + a.name + '_' + item2;
            var h = parseInt(a.fns[item2]/4);
            $(j).css ('height', h + 'px');
        });


    });

    var fields = Object.keys (company.sfns);
    fields.forEach (function (item, index, array) {
        var i = '#company_' + item;
        var h = parseInt(company.sfns[item]/4);
        $(i).css ('height', h + 'px');
    });

    // erase old threats
    var i, j;
    for (i=0; i<10; i++) {
        for (j=0; j<3; j++) {
            var s = "#threat_" + j + "_" + i;
            $(s).css ('height', '0px');
            //console.log ("setting " + s);
        }
    }

    // draw threats
    company.threats.forEach (function (item, index, array) {
        var t = item;
        var i = '#threat_' + item.range + "_" + item.pos;
        var h = parseInt(item.strength/4);
        $(i).css ('height', h + 'px');
    });

    var m = "<table>";
    company.messages.forEach ( 
        function (item, index, array) 
           { m += "<tr><td>" + item.message + "</td></tr>";} );
    m += "</table>";
    $("#cmsgs").html (m);

} // updateCompany

function updatePlayer () {

    $("#score").text (player.score);
    $("#budget").text (player.budget);

    // update message block
    if (recent_messages.length > 5) {
        recent_messages = recent_messages.slice (recent_messages.length - 5);
    } // if
    var h = "<table>";
    recent_messages.forEach ( 
        function (item, index, array) 
           { h += "<tr><td>" + item + "</td></tr>";} );
    h += "</table>";
    $("#pmsgs").html (h);

    ////////////
    // iterate through player skills and areas
    var fields = Object.keys (player.skills);
    fields.forEach (function (item, index, array) {
        var i = '#skillbox_' + item;
        var h = parseInt(player.skills[item]/4);
        $(i).css ('height', h + 'px');

        // the buttons
        i = '#active_' + item;
        var action = '';
        if (parseInt (player.areas[item]) > 0) {

            action = "disable";
        }
        else {
            action = "enable";
        }
        $(i).prop ('value', action);
    });

    setAction (empty_action, 0);
    setAction (empty_action, 1);
    setAction (empty_action, 2);
    setAction (empty_action, 3);

    var actions = Object.keys (player.actions);
    actions.forEach (function (item, index, array) {
        var a = player.actions[item];
        setAction (a, a.an);
    });


} // updatePlayer

function setAction (action, num) {
    var prefix = "#action_" + num + "_";
    var f = prefix + "name";
    $(f).text (action.name);

    f = prefix + "time";
    $(f).text (action.time); 

    f = prefix + "difficulty";
    $(f).text (action.difficulty); 

    f = prefix + "cost";
    $(f).text (action.cost); 

    f = prefix + "description";
    $(f).text (action.description); 

    f = prefix + "doit";
    if (parseInt (action.id) > 0) {
        $(f).html ("<input type='button' value='do it' onclick='send_action(1," + action.id + ")'></input>");
        f = prefix + "dismiss";
        $(f).html ("<input type='button' value='dismiss' onclick='send_action(0,"+action.id + ")'></input>");
    } 
    else {
        $(f).html (""); 
        f = prefix + "dismiss";
        $(f).html (""); 
    }
} // setAction

function addMessage (message) {
    var new_time = new Date().getTime() - load_time;
    var secs = Math.round (new_time / 1000);
    recent_messages.push (secs + ". " + message);
}

function toggle_area (area) {
    if (countdown > 0) {
        addMessage ("current action not done yet");
        updateCompany();
        updatePlayer();
        return;
    }

    var i = '#active_' + area;
    var action = $(i).attr("value");

    $.get ("/ww/" + player_id + "/" + action + "/" + area, toggleReply);
    startAction (action + " " + area, 3000);
} // toggle_area

function send_action (doit, id) {
    if (countdown > 0) {
        addMessage ("current action not done yet");
        updateCompany();
        updatePlayer();
        return;
    }

    if (parseInt (doit) == 1) {
       addMessage ("starting: " + player.actions[id].name);
       startAction (player.actions[id].name, parseInt (player.actions[id].time) * 1000);
    }
    else {
       addMessage ("dismissing: " + player.actions[id].name);
       startAction ("dismissing " + player.actions[id].name, 1000);
    }
    $.get ("/ww/" + player_id + "/action/" + doit + "/" + id, actionReply);
    

} // send_action

function actionReply (e) {
    //addMessage ("got a reply");
    player = e.p;
    company = e.c;
    addMessage (e.msg);
    updateCompany ();
    updatePlayer ();

} // actionReply



function setup (e) {
    player = e.p;
    company = e.c;
    updateCompany ();
    updatePlayer ();
} // setup

function toggleReply (e) {
    player = e.p;
    company = e.c;
    addMessage (e.msg);
    updateCompany ();
    updatePlayer ();
} // toggleReply

function startAction (name, ms) {
    countdown = parseInt (ms / 1000);
    $("#busy_bar").css ('height', '50px');
    $("#current_action").text (name);
    $("#countdown").text (countdown);
    $("#busy_bar").animate ({height: '0px'}, ms, function () {
        $("#current_action").text ("ready");
        $("#countdown").text ("");
    });
}