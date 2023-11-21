<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0">
    <xsl:output method="text" encoding="UTF-8" omit-xml-declaration="yes"/>
    <xsl:strip-space elements="*"/>
    
    <xsl:template match="book">
        <xsl:variable name="siglum" select="@siglum"/>
        <xsl:for-each select="module[@type='pages']/page">
            <xsl:variable name="pagenumber" select="pagenumber"/>
            {"page":"<xsl:value-of select="pagenumber"/>",
            "rt":"<xsl:choose><xsl:when test="zone">yes</xsl:when><xsl:otherwise>no</xsl:otherwise></xsl:choose>"
            <xsl:if test="ancestor::module//zone">,
                "rtr":[
                <xsl:for-each select="zone">
                    {"nr":"<xsl:value-of select="number"/>",
                    "facsimile":"<xsl:value-of select="facsimile"/>",
                    "top":"<xsl:if test="position != ''"><xsl:if test="not(@move)"><xsl:value-of select="position * 3 div 4"/></xsl:if><xsl:if test="@move"><xsl:value-of select="position * 3 div 4 - 20"/></xsl:if></xsl:if>px",
                    "transcription":"<xsl:apply-templates select="rn/transcription"/>",
                    "extract":"<xsl:apply-templates select="rn/extracts"/>",
                    "WritingTool":"<xsl:value-of select="rn/writingtool"/>",
                    "img_width":"<xsl:choose><xsl:when test="@rotate"><xsl:value-of select="coordinates/four - coordinates/two"/></xsl:when><xsl:otherwise><xsl:value-of select="coordinates/three - coordinates/one"/></xsl:otherwise></xsl:choose>"
                    <xsl:if test="rn/transcription/m">,
                        "marginalia":"yes"</xsl:if>
                    <xsl:if test="rn/manuscriptlink">,
                        "Reftext":"<xsl:apply-templates select="rn/manuscriptlink"/>"</xsl:if>
                    }<xsl:if test="position() != last()">,</xsl:if>
                </xsl:for-each>
                ]</xsl:if>}
            <xsl:if test="position()!=last()">,</xsl:if>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="rn/transcription">
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="rn/extracts"><xsl:apply-templates mode="extracts"/></xsl:template>
    
    <xsl:template match="ref">&lt;a style=\'color:#999967;\' href=\'../<xsl:value-of select="substring-before(@target,':')"/>/<xsl:value-of select="substring-before(substring-after(@target,':'),',')"/>/<xsl:if test="@type='pagelink'"><xsl:value-of select="substring-before(substring-after(@target,','),'[')"/>?view=imagetext#Ann_<xsl:value-of select="substring-before(substring-after(@target,'['),']')"/></xsl:if><xsl:if test="@type='sentencelink'"><xsl:value-of select="substring-after(@target,',')"/></xsl:if>\'&gt;<xsl:apply-templates/>&lt;/a&gt;</xsl:template>
    
    <xsl:template match="i">&lt;i&gt;<xsl:apply-templates/>&lt;/i&gt;</xsl:template>
    <xsl:template match="hi[@rend='circled']">&lt;em&gt;<xsl:apply-templates/>&lt;/em&gt;</xsl:template>
    <xsl:template match="sup">&lt;sup&gt;<xsl:apply-templates/>&lt;/sup&gt;</xsl:template>
    <xsl:template match="add">&lt;sup&gt;<xsl:apply-templates/>&lt;/sup&gt;</xsl:template>
    <xsl:template match="del">&lt;del&gt;<xsl:apply-templates/>&lt;/del&gt;</xsl:template>
    <xsl:template match="u">&lt;u&gt;<xsl:apply-templates/>&lt;/u&gt;</xsl:template>
    <xsl:template match="p"><xsl:apply-templates/>&lt;br/&gt;</xsl:template>
    <xsl:template match="lb"><xsl:apply-templates/>&lt;br/&gt;</xsl:template>
    <xsl:template match="unclear">[<xsl:apply-templates/>]</xsl:template>
    
    <xsl:template match="i" mode="extracts">&lt;i&gt;<xsl:apply-templates mode="extracts"/>&lt;/i&gt;</xsl:template>
    <xsl:template match="hi[@rend='circled']" mode="extracts">&lt;em&gt;<xsl:apply-templates mode="extracts"/>&lt;/em&gt;</xsl:template>
    <xsl:template match="sup" mode="extracts">&lt;sup&gt;<xsl:apply-templates mode="extracts"/>&lt;/sup&gt;</xsl:template>
    <xsl:template match="add" mode="extracts">&lt;sup&gt;<xsl:apply-templates mode="extracts"/>&lt;/sup&gt;</xsl:template>
    <xsl:template match="del" mode="extracts">&lt;del&gt;<xsl:apply-templates mode="extracts"/>&lt;/del&gt;</xsl:template>
    <xsl:template match="u" mode="extracts">&lt;u&gt;<xsl:apply-templates mode="extracts"/>&lt;/u&gt;</xsl:template>
    <xsl:template match="p" mode="extracts"><xsl:apply-templates mode="extracts"/>&lt;br/&gt;</xsl:template>
    <xsl:template match="lb" mode="extracts"><xsl:apply-templates mode="extracts"/>&lt;br/&gt;</xsl:template>
    <xsl:template match="unclear" mode="extracts">[<xsl:apply-templates mode="extracts"/>]</xsl:template>
    
    <!--<xsl:template match="text()" name="insertBreaks" mode="extracts"><xsl:param name="pText" select="."/><xsl:param name="apos">/ </xsl:param><xsl:param name="replace">&lt;br/&gt; </xsl:param><xsl:choose><xsl:when test="not(contains($pText, $apos))"><xsl:copy-of select="$pText"/></xsl:when><xsl:otherwise><xsl:value-of select="substring-before($pText, $apos)"/>&lt;br/&gt;<xsl:call-template name="insertBreaks"><xsl:with-param name="pText" select="substring-after($pText, $apos)"/></xsl:call-template></xsl:otherwise></xsl:choose></xsl:template>-->
    
    <xsl:template match="text()" mode="extracts"><xsl:variable name="s-quote">'</xsl:variable><xsl:variable name="d-quote">"</xsl:variable><xsl:value-of select="replace(replace(replace(replace(.,'&#xA;',' '),$d-quote,concat('\\',$d-quote)),$s-quote,concat('\\',$s-quote)),'/','&lt;br/&gt;')"/></xsl:template>
    
    <xsl:template match="text()"><xsl:variable name="s-quote">'</xsl:variable><xsl:variable name="d-quote">"</xsl:variable><xsl:if test="ancestor::manuscriptlink"><xsl:value-of select="replace(replace(replace(.,'&#xA;',' '),$d-quote,concat('\\',$d-quote)),$s-quote,concat('\\',$s-quote))"/></xsl:if><xsl:if test="not(ancestor::manuscriptlink)"><xsl:value-of select="replace(replace(replace(replace(.,'&#xA;',' '),$d-quote,concat('\\',$d-quote)),$s-quote,concat('\\',$s-quote)),'/','&lt;br/&gt;')"/></xsl:if></xsl:template>
</xsl:stylesheet>