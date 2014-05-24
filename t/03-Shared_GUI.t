#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

BEGIN {
    use_ok( 'AdminPanel::Shared::GUI' ) || print "AdminPanel::Shared::GUI failed!\n";
    use_ok( 'AdminPanel::Shared' ) || print "AdminPanel::Shared failed!\n";
}

    ok( my $gui = AdminPanel::Shared::GUI->new(), 'create');

    diag "\n\nNext tests will create some gui dialogs";
    diag "Perform tests (y/n) [n] ?";

    my $a = <>; chomp $a; $a = "n" unless $a;

    SKIP: {
        #remember to skip the righ number of tests
        skip "You didn't say yes...", 10, unless ( $a eq "y" );

        ok( $gui->warningMsgBox({text => "Warning message! (no title, no richtext)<br> line two"}), 'wmb1');

        ok( $gui->warningMsgBox({text => "Warning message!<br> line two", title => "WARN", reachtext => 1}), 'wmb2');

        ok($gui->infoMsgBox({text => "Info message!<br> line two", title => "INFO", reachtext => 1}), 'imb');

        ok($gui->msgBox({text => "Normal message! (no title, no richtext)<br> line two"}), 'mb1');

        ok($gui->msgBox({title => "Message", text => "Normal message!<br> line two", reachtext=>1}), 'mb2');

        cmp_ok(my $btn = $gui->ask_OkCancel({title => "Tests", text => "All these tests seem to be passed"}), ">=", 0, 'askOkCancel');
        diag "ask_OkCancel got: < " . ($btn == 1 ? "Ok": "Cancel"). " >";

        cmp_ok($btn = $gui->ask_YesOrNo({title => "Question on tests", text => "Did these tests all pass?"}), ">=", 0, 'ask_YesOrNo');
        diag "ask_YesOrNo got: < " . ($btn == 1 ? "Yes": "No"). " >";
        
        #TODO cancel makes this test failing
        ok(my $item = $gui->ask_fromList({title => "Choose from list", header => "Which one do you select?", default_button => 1, 
                                          list  => ['item 1', 'item 2', 'item 3', 'item 4']}), 'ask_fromList');
        diag "ask_fromList got: < " . ($item ? $item : "none") . " >";
        ok($gui->AboutDialog({ name => "Shared::GUI TABBED",
                           version => $AdminPanel::Shared::VERSION,
                           credits => "Copyright (C) 2014 Angelo Naselli",
                           license => $AdminPanel::Shared::License, 
                           authors => "Angelo Naselli <anaselli\@linux.it>\nMatteo Pasotti <matteo.pasotti\@gmail.com>",
                        }), 'AboutDialog'); 

        ok($gui->AboutDialog({ name => "Shared::GUI CLASSIC",
                           version => $AdminPanel::Shared::VERSION,
                           credits => "Copyright (C) 2014 Angelo Naselli",
                           license => $AdminPanel::Shared::License, 
                           authors => "Angelo Naselli <anaselli\@linux.it>\nMatteo Pasotti <matteo.pasotti\@gmail.com>",
                           dialog_mode => 1,
                        }), 'ClassicAboutDialog');    
    }
         

    #TODO $gui->AboutDialog


done_testing;
