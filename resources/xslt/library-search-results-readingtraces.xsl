<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:exist="http://exist-db.org/ns/1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="xs" version="2.0">
    <xsl:output method="html"/>
    
    
    <xsl:template match="i"><i><xsl:apply-templates/></i></xsl:template>
    <xsl:template match="hi[@rend='circled']"><em><xsl:apply-templates/></em></xsl:template>
    <xsl:template match="sup"><sup><xsl:apply-templates/></sup></xsl:template>
    <xsl:template match="add"><sup><xsl:apply-templates/></sup></xsl:template>
    <xsl:template match="del"><del><xsl:apply-templates/></del></xsl:template>
    <xsl:template match="u"><u><xsl:apply-templates/></u></xsl:template>
    <xsl:template match="p"><xsl:apply-templates/><br/></xsl:template>
    <xsl:template match="lb"><br/></xsl:template>
    <xsl:template match="unclear">[<xsl:apply-templates/>]</xsl:template>
    
    <xsl:template match="*[local-name() = 'match']">
        <span class="hi"><xsl:apply-templates/></span>
    </xsl:template>
    
    <!--<xsl:template match="text()">
        <xsl:variable name="lb"><br/></xsl:variable>
        <xsl:value-of select="replace(.,'/','&#10;')"/>
    </xsl:template>-->
    <xsl:template match="text()" name="insertBreaks"><xsl:param name="pText" select="."/><xsl:param name="apos">/</xsl:param><xsl:param name="replace"><br/></xsl:param><xsl:choose><xsl:when test="not(contains($pText, $apos))"><xsl:copy-of select="$pText"/></xsl:when><xsl:otherwise><xsl:value-of select="substring-before($pText, $apos)"/><br/><xsl:call-template name="insertBreaks"><xsl:with-param name="pText" select="substring-after($pText, $apos)"/></xsl:call-template></xsl:otherwise></xsl:choose></xsl:template>
    
</xsl:stylesheet>