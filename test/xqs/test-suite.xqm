xquery version "3.1";

(:~ This library module contains XQSuite tests for the writerslibrary app.
 :
 : @author Antwerp Toolkit for Digital Scholarly Editing
 : @version 1.0.0
 : @see https://www.uantwerpen.be/CMG
 :)

module namespace tests = "http://exist-db.org/apps/writerslibrary/tests";

import module namespace app = "http://exist-db.org/apps/writerslibrary/templates" at "../../modules/app.xqm";
 
declare namespace test="http://exist-db.org/xquery/xqsuite";


declare variable $tests:map := map {1: 1};

declare
    %test:name('dummy-templating-call')
    %test:arg('n', 'div')
    %test:assertEquals("<p>Dummy templating function.</p>")
    function tests:templating-foo($n as xs:string) as node(){
        app:foo(element {$n} {}, $tests:map)
};
