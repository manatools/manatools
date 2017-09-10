use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

BEGIN {
    use_ok( 'ManaTools::Shared::GUI' ) || print "ManaTools::Shared::GUI failed!\n";
    use_ok( 'ManaTools::Shared' ) || print "ManaTools::Shared failed!\n";
}

    is (ManaTools::Shared::distName(), 'manatools', 'distname');

    ok( my $gui = ManaTools::Shared::GUI->new(), 'create');

SKIP: {
    #remember to skip the right number of tests
    skip "To enable dialog tests set TEST_GUI", 11, unless $ENV{TEST_GUI};

    ok( $gui->warningMsgBox({text => "Warning message! (no title, no richtext)<br> line two"}), 'wmb1');

    ok( $gui->warningMsgBox({text => "Warning message!<br> line two", title => "WARN", richtext => 1}), 'wmb2');

    ok($gui->infoMsgBox({text => "Info message!<br> line two", title => "INFO", richtext => 1}), 'imb');

    ok($gui->msgBox({text => "Normal message! (no title, no richtext)<br> line two"}), 'mb1');

    ok($gui->msgBox({title => "Message", text => "Normal message!<br> line two", richtext=>1}), 'mb2');

    cmp_ok(my $btn = $gui->ask_OkCancel({title => "Tests", text => "All these tests seem to be passed"}), ">=", 0, 'askOkCancel');
    diag "ask_OkCancel got: < " . ($btn == 1 ? "Ok": "Cancel"). " >";

    cmp_ok($btn = $gui->ask_YesOrNo({title => "Question on tests", text => "Did these tests all pass?"}), ">=", 0, 'ask_YesOrNo');
    diag "ask_YesOrNo got: < " . ($btn == 1 ? "Yes": "No"). " >";

    #TODO cancel makes this test failing
    ok(my $item = $gui->ask_fromList({title => "Choose from list", header => "Which one do you select? [default is item 3]", default_button => 1,
                                        list  => ['item 1', 'item 2', 'item 3', 'item 4'],
                                        default_item => 'item 3'
    }), 'ask_fromList');
    diag "ask_fromList got: < " . ($item ? $item : "none") . " >";

    ok( my $mul_selection = $gui->ask_multiple_fromList({
        title => "Choose from list",
        header => "What do you have selected?",
        list  => [
            map {
                {
                    id => $_->{id},
                    text=>$_->{text},
                    val => \$_->{val}
                },
            } (
               {id => "a",val=>1,text=>"Item 1"},
               {id => "b",val=>0, text=>"Item 2"},
               {id => "c",val=>1,text=>"Item 3"},
               {id => "d",val=>0,text=>"Item 4"}
              )],
    }), 'ask_multiple_fromList');
    diag "ask_multiple_fromList got: < " . join(' - ', @${mul_selection}) . " >";

    ok(my $selection = $gui->select_fromList({
        title => "Select from list",
        header => {
            text_column  => "Items",
            check_column => "selected",
        },
        list  => [
         { text => 'item 1', checked => 1},
         { text => 'item 2', },
         { text => 'item 3', checked => 0},
         { text => 'item 4', checked => 1},
         { text => 'item 5',},
        ],
    }), 'select_fromList');
    diag "select_fromList got: < " . join(' - ', @${selection})  . " >";

    #TODO cancel makes this test failing
    ok($item = $gui->ask_fromTreeList({title => "Choose from a tree", header => "Which one do you select? [default is leaf 2]", default_button => 1,
                                        default_item => 'leaf 2',
                                    list  => ['item 1/item 2/item 3', 'item 1/item 2/leaf 1', 'item 1/item 2/leaf 2', 'item 4/leaf 3', 'item 5']}),
                                    'ask_fromTreeList');
    diag "ask_fromTreeList got: < " . ($item ? $item : "none") . " >";

    ok($gui->AboutDialog({ name => "Shared::GUI TABBED",
                    version => $ManaTools::Shared::VERSION,
                    credits => "Copyright (C) 2014-2017 Angelo Naselli",
                    license => 'GPLv2',
                    authors => "Angelo Naselli <anaselli\@linux.it>\nMatteo Pasotti <matteo.pasotti\@gmail.com>",
                    }), 'AboutDialog');

    ok($gui->AboutDialog({ name => "Shared::GUI CLASSIC",
                    version => $ManaTools::Shared::VERSION,
                    credits => "Copyright (C) 2014-2017 Angelo Naselli",
                    license => 'GPLv2',
                    authors => "Angelo Naselli <anaselli\@linux.it>\nMatteo Pasotti <matteo.pasotti\@gmail.com>",
                    dialog_mode => 1,
                    }), 'ClassicAboutDialog');
}


done_testing;
