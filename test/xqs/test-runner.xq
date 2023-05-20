xquery version "3.1";

(:~ This library runs the XQSuite unit tests for the writerslibrary app.
 :
 : @author Antwerp Toolkit for Digital Scholarly Editing
 : @version 1.0.0
 : @see http://www.exist-db.org/exist/apps/doc/xqsuite
 :)
import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";
import module namespace tests="http://exist-db.org/apps/writerslibrary/tests" at "test-suite.xqm";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "json";
declare option output:media-type "application/json";

test:suite(
  inspect:module-functions(xs:anyURI("test-suite.xqm"))
)
