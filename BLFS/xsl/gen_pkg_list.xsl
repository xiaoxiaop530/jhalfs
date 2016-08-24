<?xml version="1.0" encoding="ISO-8859-1"?>

<!-- $Id: gen_pkg_list.xsl 21 2012-02-16 15:06:19Z labastie $ -->
<!-- Takes the blfs-full.xml file and extract a list
     of packages obeying packdesc.dtd + looks for already
     installed packages in the tracking file (stringparam
     'installed-packages') -->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    version="1.0">

  <xsl:param name="installed-packages" select="'../lib/instpkg.xml'"/>

  <xsl:output method="xml"
              encoding='ISO-8859-1'
              doctype-system="./packdesc.dtd"/>

<!-- specialCases.xsl is generated by a shell script:
     allows for cases where version begins with a letter
     and when there is no version (such as xorg7 packages) -->
  <xsl:include href="./specialCases.xsl"/>

  <xsl:template match="/">
    <princList>
    <xsl:text>&#xA;&#xA;</xsl:text>
<!-- How to have blfs-bootscripts versionned? Do not know, so
     avoid it (TODO ?) -->
      <xsl:apply-templates select="//part[not(@id='introduction')]"/>
    </princList>
  </xsl:template>

  <xsl:template match="part">
    <xsl:if test="count(.//*[contains(translate(@xreflabel,
                                               '123456789',
                                               '000000000'),
                                      '-0')
                            ]) &gt; 0">
      <xsl:text>  </xsl:text>
      <list>
        <xsl:attribute name="id"><xsl:value-of select="@id"/></xsl:attribute>
        <xsl:text>&#xA;    </xsl:text>
        <xsl:element name="name">
           <xsl:value-of select="normalize-space(title)"/>
        </xsl:element>
        <xsl:text>&#xA;&#xA;</xsl:text>
        <xsl:apply-templates select="chapter"/>
        <xsl:text>  </xsl:text>
      </list>
      <xsl:text>&#xA;&#xA;</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="chapter">
    <xsl:if test="count(.//*[contains(translate(@xreflabel,
                                               '123456789',
                                               '000000000'),
                                      '-0')
                            ]) &gt; 0">
      <xsl:text>    </xsl:text>
      <sublist>
        <xsl:attribute name="id"><xsl:value-of select="@id"/></xsl:attribute>
        <xsl:text>&#xA;      </xsl:text>
        <xsl:element name="name">
          <xsl:value-of select="normalize-space(title)"/>
        </xsl:element>
        <xsl:text>&#xA;</xsl:text>
        <xsl:apply-templates select=".//sect1">
          <xsl:sort select="@id"/>
        </xsl:apply-templates>
      <xsl:text>    </xsl:text>
      </sublist><xsl:text>&#xA;&#xA;</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="sect1">
    <xsl:choose>
<!-- This test is to find sections containing modules (PERL, Python
      DBus,...) -->
      <xsl:when
        test="not(contains(translate(@xreflabel,
                                     '123456789',
                                     '000000000'),
                           '-0')) and
              count(descendant::node()[contains(translate(@xreflabel,
                                                         '123456789',
                                                         '000000000'),
                                                '-0')
                                      ]) &gt; 0">
        <xsl:text>      </xsl:text>
        <package><xsl:text>&#xA;        </xsl:text>
          <xsl:element name="name">
            <xsl:value-of select="normalize-space(title)"/>
            </xsl:element>
          <xsl:text>&#xA;</xsl:text>
<!-- Do not use .//*, which would include self. -->
          <xsl:apply-templates
            select="descendant::node()[contains(translate(@xreflabel,
                                                         '123456789',
                                                         '000000000'),
                                                '-0')    
                                      ]"
            mode="normal">
            <xsl:sort select="@id"/>
          </xsl:apply-templates>
          <xsl:text>      </xsl:text>
        </package><xsl:text>&#xA;&#xA;</xsl:text>
      </xsl:when>
      <xsl:otherwise>
<!-- Calls the template of specialCases.xsl,
     which calls the "normal" template when the
     case is normal. -->
        <xsl:apply-templates select='.' mode="special">
          <xsl:sort select="@id"/>
        </xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="*" mode="normal">
    <xsl:variable name="version">
      <xsl:call-template name="version">
        <xsl:with-param name="label" select="./@xreflabel"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:choose>
<!-- If there is a "sect1" ancestor, this means that
     we have a module -->
      <xsl:when test="ancestor::sect1">
        <xsl:text>        </xsl:text>
        <module><xsl:text>&#xA;          </xsl:text>
          <xsl:element name="name">
            <xsl:value-of select="./@id"/>
          </xsl:element>
          <xsl:text>&#xA;          </xsl:text>
          <xsl:element name="version">
            <xsl:value-of select="$version"/>
          </xsl:element>
          <xsl:if
              test="document($installed-packages)//package[name=current()/@id]">
            <xsl:text>&#xA;          </xsl:text>
            <xsl:element name="inst-version">
              <xsl:value-of
                select="document(
                         $installed-packages
                                )//package[name=current()/@id]/version"/>
            </xsl:element>
          </xsl:if>
<!-- Dependencies -->
<!-- First the case of python modules or d-bus bindings -->
          <xsl:if test="self::sect2">
<!-- dependencies  -->
            <xsl:apply-templates select=".//para[@role='required' or
                                                 @role='recommended' or
                                                 @role='optional']"
                                 mode="dependency"/>
          </xsl:if>
<!-- For python modules, the preceding module is an optional dep -->
            <xsl:if test="ancestor::sect1[@id='python-modules']">
              <xsl:apply-templates
                  select="preceding-sibling::sect2[@role='package']
                           //listitem[para/xref/@linkend=current()/@id]"
                  mode="prec-dep"/>
            </xsl:if>
<!-- Now the case of perl modules: let us test our XSLT abilities.
     Well, "use the sibling, Luke" -->
          <xsl:if test="self::bridgehead">
            <xsl:apply-templates select="following-sibling::itemizedlist[1]
                                        /listitem/itemizedlist/listitem"
                                 mode="perlmod-dep">
               <xsl:sort select="position()"
                         data-type="number"
                         order="descending"/>
            </xsl:apply-templates>
          </xsl:if>
<!-- End dependencies -->
          <xsl:text>&#xA;        </xsl:text>
        </module><xsl:text>&#xA;</xsl:text>
      </xsl:when>
      <xsl:otherwise>
         <xsl:text>      </xsl:text>
        <package><xsl:text>&#xA;        </xsl:text>
          <xsl:element name="name">
            <xsl:value-of select="./@id"/>
          </xsl:element>
          <xsl:text>&#xA;        </xsl:text>
          <xsl:element name="version">
            <xsl:value-of select="$version"/>
          </xsl:element>
          <xsl:if
              test="document($installed-packages)//package[name=current()/@id]">
            <xsl:text>&#xA;        </xsl:text>
            <xsl:element name="inst-version">
              <xsl:value-of
                select="document(
                         $installed-packages
                                )//package[name=current()/@id]/version"/>
            </xsl:element>
          </xsl:if>
<!-- Dependencies -->
<!-- If in Xorg (not anymore) or KDE chapter, consider that the preceding
     package is the first dependency (not always noted in the book)-->
          <xsl:if test="ancestor::chapter[@id='kde4-core'
                                       or @id='xfce-core'
                                       or @id='lxqt-desktop'
                                       or @id='lxde-desktop']
                    and preceding-sibling::sect1[1]">
            <xsl:text>
            </xsl:text>
            <xsl:element name="dependency">
              <xsl:attribute name="status">required</xsl:attribute>
              <xsl:attribute name="name">
                <xsl:value-of select="preceding-sibling::sect1[1]/@id"/>
              </xsl:attribute>
              <xsl:attribute name="type">ref</xsl:attribute>
            </xsl:element>
          </xsl:if>
          <xsl:apply-templates select=".//para[@role='required' or
                                               @role='recommended' or
                                               @role='optional']"
                               mode="dependency"/>
<!-- End dependencies -->
          <xsl:text>&#xA;      </xsl:text>
        </package><xsl:text>&#xA;</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="version">
    <xsl:param name="label" select="abc-2"/>
    <xsl:variable name="start" select="string-length(substring-before(translate($label,'123456789','000000000'),'-0'))+2"/>
    <xsl:variable name="prelim-ver" select="substring($label,$start)"/>
    <xsl:choose>
      <xsl:when test="contains($prelim-ver,'onfiguration')"/>
      <xsl:when test="contains($prelim-ver,'escription')"/>
      <xsl:when test="contains($prelim-ver,'EggDBus')">
        <xsl:value-of select="substring-before($prelim-ver,' (EggDBus)')"/>
      </xsl:when>
      <xsl:when test="contains($label,'JDK')">
        <xsl:value-of select="translate($prelim-ver,' ','_')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$prelim-ver"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="para" mode="dependency">
    <xsl:variable name="status" select="./@role"/>
<!-- First internal dependencies -->
    <xsl:for-each select="./xref">
      <xsl:choose>
<!-- Avoid depending of myself -->
        <xsl:when test="ancestor::*[@id=current()/@linkend]"/>
<!-- Call list expansion when we have an xorg7 series of packages -->
        <xsl:when test="contains(@linkend,'xorg7-')">
          <xsl:call-template name="expand-deps">
            <xsl:with-param name="section">
              <xsl:value-of select="@linkend"/>
            </xsl:with-param>
            <xsl:with-param name="status">
              <xsl:value-of select="$status"/>
            </xsl:with-param>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>
            </xsl:text>
          <xsl:element name="dependency">
            <xsl:attribute name="status">
              <xsl:value-of select="$status"/>
            </xsl:attribute>
            <xsl:attribute name="name">
              <xsl:value-of select="@linkend"/>
            </xsl:attribute>
            <xsl:attribute name="type">ref</xsl:attribute>
          </xsl:element>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
<!-- then external dependencies -->
    <xsl:for-each select="./ulink">
      <xsl:text>
            </xsl:text>
      <xsl:element name="dependency">
        <xsl:attribute name="status">
          <xsl:value-of select="$status"/>
        </xsl:attribute>
        <xsl:attribute name="name">
          <xsl:value-of select="translate(normalize-space(text()),' ','-')"/>
        </xsl:attribute>
        <xsl:attribute name="type">link</xsl:attribute>
      </xsl:element>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="listitem" mode="prec-dep">
    <xsl:if test="preceding-sibling::listitem">
      <xsl:text>
            </xsl:text>
      <xsl:element name="dependency">
<!-- the dep on the preceding package used to be required for python.
     It seems optional now -->
        <xsl:attribute name="status">optional</xsl:attribute>
        <xsl:attribute name="name">
          <xsl:value-of select="preceding-sibling::listitem[1]//@linkend"/>
        </xsl:attribute>
        <xsl:attribute name="type">ref</xsl:attribute>
      </xsl:element>
    </xsl:if>
  </xsl:template>

  <xsl:template match="listitem" mode="perlmod-dep">
    <xsl:param name="glue" select="'&#xA;            '"/>
    <xsl:choose>
     <xsl:when test="para/xref|para[@id]/ulink">
      <xsl:value-of select="$glue"/>
      <xsl:element name="dependency">
        <xsl:attribute name="status">
          <xsl:choose>
            <xsl:when
              test="count(./para/text()[contains(string(),
                                             'ptional')
                                   ]
                         )&gt;0">optional</xsl:when>
            <xsl:otherwise>required</xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
        <xsl:attribute name="name">
          <xsl:if test="para/xref">
            <xsl:value-of select="para/xref/@linkend"/>
          </xsl:if>
          <xsl:if test="para/ulink">
            <xsl:value-of select="para/@id"/>
          </xsl:if>
        </xsl:attribute>
        <xsl:attribute name="type">
          <xsl:if test="para/xref">ref</xsl:if>
          <xsl:if test="para/ulink">link</xsl:if>
        </xsl:attribute>
        <xsl:apply-templates select="itemizedlist/listitem"
                             mode="perlmod-dep">
           <xsl:sort select="position()"
                     data-type="number"
                     order="descending"/>
          <xsl:with-param name="glue" select="concat($glue,'  ')"/>
        </xsl:apply-templates>
      </xsl:element>
     </xsl:when>
     <xsl:otherwise>
       <xsl:apply-templates select="itemizedlist/listitem"
                            mode="perlmod-dep">
         <xsl:sort select="position()"
                   data-type="number"
                   order="descending"/>
         <xsl:with-param name="glue" select="$glue"/>
       </xsl:apply-templates>
     </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
