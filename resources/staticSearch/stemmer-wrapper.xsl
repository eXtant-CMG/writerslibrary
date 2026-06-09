<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:ss="http://hcmc.uvic.ca/ns/ssStemmer" xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="#all" version="3.0">
    
    <xd:doc xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" scope="stylesheet">
        <xd:desc>
            <xd:p>Batch stemming wrapper for staticSearch's Porter2 stemmer (ssStemmer.xsl).
            Takes an input document of the form:
            <xd:pre>
                &lt;words&gt;
                    &lt;word&gt;reading&lt;/word&gt;
                    &lt;word&gt;usually&lt;/word&gt;
                    ...
                &lt;/words&gt;
            </xd:pre>
            Returns:
            <xd:pre>
                &lt;stems&gt;
                    &lt;stem original="reading"&gt;read&lt;/stem&gt;
                    &lt;stem original="usually"&gt;usual&lt;/stem&gt;
                    ...
                &lt;/stems&gt;
            </xd:pre>
            Called from XQuery via transform:transform().
            The calling XQuery then converts the result into a map(xs:string, xs:string)
            keyed on the original word form.
            </xd:p>
        </xd:desc>
    </xd:doc>
    
    <!--  Include the Porter2 stemmer.
          Path must match where ssStemmer.xsl is stored in the eXist-db database. -->
    <xsl:include href="/db/apps/writerslibrary/resources/staticSearch/stemmers/en/ssStemmer.xsl"/>
    
    <xsl:template match="/words">
        <stems>
            <xsl:apply-templates select="word"/>
        </stems>
    </xsl:template>
    
    <xsl:template match="word">
        <stem original="{.}">
            <xsl:value-of select="ss:stem(string(.))"/>
        </stem>
    </xsl:template>
    
</xsl:stylesheet>