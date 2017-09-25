<!-- Collection of all global variables for the result pages of single cancer study query-->

<%@ page import="org.mskcc.cbio.portal.servlet.QueryBuilder" %>
<%@ page import="java.util.ArrayList" %>
<%@ page import="java.util.HashSet" %>
<%@ page import="org.mskcc.cbio.portal.model.*" %>
<%@ page import="java.text.NumberFormat" %>
<%@ page import="java.text.DecimalFormat" %>
<%@ page import="java.util.Set" %>
<%@ page import="java.util.Iterator" %>
<%@ page import="org.mskcc.cbio.portal.servlet.ServletXssUtil" %>
<%@ page import="java.util.Enumeration" %>
<%@ page import="java.net.URLEncoder" %>
<%@ page import="org.mskcc.cbio.portal.oncoPrintSpecLanguage.CallOncoPrintSpecParser" %>
<%@ page import="org.mskcc.cbio.portal.oncoPrintSpecLanguage.ParserOutput" %>
<%@ page import="org.mskcc.cbio.portal.oncoPrintSpecLanguage.OncoPrintSpecification" %>
<%@ page import="org.mskcc.cbio.portal.oncoPrintSpecLanguage.Utilities" %>
<%@ page import="org.mskcc.cbio.portal.model.CancerStudy" %>
<%@ page import="org.mskcc.cbio.portal.model.SampleList" %>
<%@ page import="org.mskcc.cbio.portal.model.GeneticProfile" %>
<%@ page import="org.mskcc.cbio.portal.model.GeneticAlterationType" %>
<%@ page import="org.mskcc.cbio.portal.model.Patient" %>
<%@ page import="org.mskcc.cbio.portal.dao.DaoGeneticProfile" %>
<%@ page import="org.apache.commons.logging.LogFactory" %>
<%@ page import="org.apache.commons.logging.Log" %>
<%@ page import="org.apache.commons.lang.StringEscapeUtils" %>
<%@ page import="java.lang.reflect.Array" %>
<%@ page import="org.mskcc.cbio.portal.util.*" %>
<%@ page import="org.codehaus.jackson.node.*" %>
<%@ page import="org.codehaus.jackson.JsonNode" %>
<%@ page import="org.codehaus.jackson.JsonParser" %>
<%@ page import="org.codehaus.jackson.JsonFactory" %>
<%@ page import="org.codehaus.jackson.map.ObjectMapper" %>

<%
    //Security Instance
    ServletXssUtil xssUtil = ServletXssUtil.getInstance();

    //Info about Genetic Profiles
    ArrayList<GeneticProfile> profileList = (ArrayList<GeneticProfile>) request.getAttribute(QueryBuilder.PROFILE_LIST_INTERNAL);
    HashSet<String> geneticProfileIdSet = (HashSet<String>) request.getAttribute(QueryBuilder.GENETIC_PROFILE_IDS);
    String geneticProfiles = StringUtils.join(geneticProfileIdSet.iterator(), " ");
    geneticProfiles = xssUtil.getCleanerInput(geneticProfiles.trim());

    //Info about threshold settings
    double zScoreThreshold = ZScoreUtil.getZScore(geneticProfileIdSet, profileList, request);
    double rppaScoreThreshold = ZScoreUtil.getRPPAScore(request);

    //Onco Query Language Parser Instance
    String oql = request.getParameter(QueryBuilder.GENE_LIST);
    if (request instanceof XssRequestWrapper) {
        oql = ((XssRequestWrapper)request).getRawParameter(QueryBuilder.GENE_LIST);
    }
    oql = xssUtil.getCleanerInput(oql);

    //Info about queried cancer study
    ArrayList<CancerStudy> cancerStudies = (ArrayList<CancerStudy>)request.getAttribute(QueryBuilder.CANCER_TYPES_INTERNAL);
    String cancerStudyId = (String) request.getAttribute(QueryBuilder.CANCER_STUDY_ID);
    CancerStudy cancerStudy = cancerStudies.get(0);
    for (CancerStudy cs : cancerStudies){
        if (cancerStudyId.equals(cs.getCancerStudyStableId())){
            cancerStudy = cs;
            break;
        }
    }
    String cancerStudyName = cancerStudy.getName(); 
    GeneticProfile mutationProfile = cancerStudy.getMutationProfile();
    String mutationProfileID = mutationProfile==null ? null : mutationProfile.getStableId();

    //Info about Patient Set(s)/Patients
    ArrayList<SampleList> sampleSets = (ArrayList<SampleList>)request.getAttribute(QueryBuilder.CASE_SETS_INTERNAL);
    String studySampleMapJson = (String)request.getAttribute("STUDY_SAMPLE_MAP");
    String sampleSetId = (String) request.getAttribute(QueryBuilder.CASE_SET_ID);
    String sampleSetName = "";
    String sampleSetDescription = "";
    for (SampleList sampleSet:  sampleSets) {
        if (sampleSetId.equals(sampleSet.getStableId())) {
            sampleSetName = sampleSet.getName();
            sampleSetDescription = sampleSet.getDescription();
        }
    }
    String samples = (String) request.getAttribute(QueryBuilder.SET_OF_CASE_IDS);
    String sampleIdsKey = (String) request.getAttribute(QueryBuilder.CASE_IDS_KEY);

    //Vision Control Tokens
    boolean showIGVtab = cancerStudy.hasCnaSegmentData();
    boolean has_mrna = countProfiles(profileList, GeneticAlterationType.MRNA_EXPRESSION) > 0;
    boolean has_methylation = countProfiles(profileList, GeneticAlterationType.METHYLATION) > 0;
    boolean has_copy_no = countProfiles(profileList, GeneticAlterationType.COPY_NUMBER_ALTERATION) > 0;
    boolean has_survival = cancerStudy.hasSurvivalData();
    boolean includeNetworks = GlobalProperties.includeNetworks();
    boolean computeLogOddsRatio = true;
    Boolean mutationDetailLimitReached = (Boolean)request.getAttribute(QueryBuilder.MUTATION_DETAIL_LIMIT_REACHED);

    //are we using session service for bookmarking?
    boolean useSessionServiceBookmark = !StringUtils.isBlank(GlobalProperties.getSessionServiceUrl());

    //General site info
    String siteTitle = GlobalProperties.getTitle();

    request.setAttribute(QueryBuilder.HTML_TITLE, siteTitle+"::Results");

    //Escape quotes in the returned strings
    samples = samples.replaceAll("'", "\\'");
    samples = samples.replaceAll("\"", "\\\"");
    sampleSetName = sampleSetName.replaceAll("'", "\\'");
    sampleSetName = sampleSetName.replaceAll("\"", "\\\"");

    //check if show co-expression tab
    boolean showCoexpTab = false;
    GeneticProfile final_gp = CoExpUtil.getPreferedGeneticProfile(cancerStudyId);
    if (final_gp != null) {
        showCoexpTab = true;
    } 
    Object patientSampleIdMap = request.getAttribute(QueryBuilder.SELECTED_PATIENT_SAMPLE_ID_MAP);
    
    String patientCaseSelect = (String)request.getAttribute(QueryBuilder.PATIENT_CASE_SELECT);

%>

<!--Global Data Objects Manager-->
<script type="text/javascript" src="js/lib/jquery.min.js?<%=GlobalProperties.getAppVersion()%>">
    //needed for data manager
</script>
<script type="text/javascript" src="js/lib/oql/oql-parser.js?<%=GlobalProperties.getAppVersion()%>"></script>
<script type="text/javascript" src="js/api/cbioportal-datamanager.js?<%=GlobalProperties.getAppVersion()%>"></script>
<script type="text/javascript" src="js/src/oql/oqlfilter.js?<%=GlobalProperties.getAppVersion()%>"></script>

<!-- Global variables : basic information about the main query -->
<script type="text/javascript">

    var num_total_cases = 0, num_altered_cases = 0;
    var global_gene_data = {}, global_sample_ids = [];
    var patientSampleIdMap = {};
    var patientCaseSelect;

    window.PortalGlobals = {
        setPatientSampleIdMap: function(_patientSampleIdMap) {patientSampleIdMap = _patientSampleIdMap;},
    };
    
    (function setUpQuerySession() {
        var oql_html_conversion_vessel = document.createElement("div");
        oql_html_conversion_vessel.innerHTML = '<%=oql%>'.trim();
        var converted_oql = oql_html_conversion_vessel.textContent.trim();
        window.QuerySession = window.initDatamanager('<%=geneticProfiles%>'.trim().split(/\s+/),
                                                            converted_oql,
                                                            ['<%=cancerStudyId%>'.trim()],
                                                            JSON.parse('<%=studySampleMapJson%>'),
                                                            parseFloat('<%=zScoreThreshold%>'),
                                                            parseFloat('<%=rppaScoreThreshold%>'),
                                                            {
                                                                case_set_id: '<%=sampleSetId%>',
                                                                case_ids_key: '<%=sampleIdsKey%>',
                                                                case_set_name: '<%=sampleSetName%>',
                                                                case_set_description: '<%=sampleSetDescription%>'
                                                            });
    })();
</script>

<script>
//Jiaojiao Dec/21/2015
//The program won't be able to get clicked checkbox elements before they got initialized and displayed. 
//Need to check every 5ms to see if checkboxes are ready or not. 
//If not ready keep waiting, if ready, then scroll to the first selected study

 function waitForElementToDisplay(selector, time) {
        if(document.querySelector(selector) !== null) {
            
           var chosenElements = document.getElementsByClassName('jstree-clicked');
            if(chosenElements.length > 0)
            {
                var treeDiv = document.getElementById('jstree');
                var topPos = chosenElements[0].offsetTop;
                var originalPos = treeDiv.offsetTop;
                treeDiv.scrollTop = topPos - originalPos;
            }
           
            return;
        }
        else {
            setTimeout(function() {
                waitForElementToDisplay(selector, time);
            }, time);
        }
    }
    
$(document).ready(function() {
    $.when(window.QuerySession.getAlteredSamples(), window.QuerySession.getPatientIds(), window.QuerySession.getCancerStudyNames()).then(function(altered_samples, patient_ids, cancer_study_names) {
            var sample_ids = window.QuerySession.getSampleIds();
            
            var altered_samples_percentage = (100 * altered_samples.length / sample_ids.length).toFixed(1);

            //Configure the summary line of alteration statstics
            var _stat_smry = "<h3 style='color:#686868;font-size:14px;'>Gene Set / Pathway is altered in <b>" + altered_samples.length + " (" + altered_samples_percentage + "%)" + "</b> of queried samples</h3>";
            $("#main_smry_stat_div").append(_stat_smry);

            //Configure the summary line of query
            var _query_smry = "<h3 style='font-size:110%;'><a href='study?id=" + 
                window.QuerySession.getCancerStudyIds()[0] + "' target='_blank'>" + 
                cancer_study_names[0] + "</a><br>" + " " +  
                "<small>" + window.QuerySession.getSampleSetName() + " (<b>" + sample_ids.length + "</b> samples)" + " / " + 
                "<b>" + window.QuerySession.getQueryGenes().length + "</b>" + " Gene" + (window.QuerySession.getQueryGenes().length===1 ? "" : "s") + "<br></small></h3>"; 
            $("#main_smry_query_div").append(_query_smry);

            //Append the modify query button
            var _modify_query_btn = "<button type='button' class='btn btn-primary' data-toggle='button' id='modify_query_btn'>Modify Query</button>";
            $("#main_smry_modify_query_btn").append(_modify_query_btn);

            //Set Event listener for the modify query button (expand the hidden form)
            $("#modify_query_btn").click(function () {
                $("#query_form_on_results_page").toggle();
                if($("#modify_query_btn").hasClass("active")) {
                    $("#modify_query_btn").removeClass("active");
                } else {
                    $("#modify_query_btn").addClass("active");    
                }
                 waitForElementToDisplay('.jstree-clicked', '5');
            });
            $("#toggle_query_form").click(function(event) {
                event.preventDefault();
                $('#query_form_on_results_page').toggle();
                //  Toggle the icons
                $(".query-toggle").toggle();
            });
            //Oncoprint summary lines
            $("#oncoprint_sample_set_description").append("Case Set: " + window.QuerySession.getSampleSetName()
							+ " "
							+ "("+patient_ids.length + " patients / " + sample_ids.length + " samples)");
            $("#oncoprint_sample_set_name").append("Case Set: "+window.QuerySession.getSampleSetName());
            if (patient_ids.length !== sample_ids.length) {
                $("#switchPatientSample").css("display", "inline-block");
            }
            
        });
   
         
        $("#toggle_query_form").click(function(event) {
            event.preventDefault();
            $('#query_form_on_results_page').toggle();
            //  Toggle the icons
            $(".query-toggle").toggle();
        });
});


</script>


<%!
    public int countProfiles (ArrayList<GeneticProfile> profileList, GeneticAlterationType type) {
        int counter = 0;
        for (int i = 0; i < profileList.size(); i++) {
            GeneticProfile profile = profileList.get(i);
            if (profile.getGeneticAlterationType() == type) {
                counter++;
            }
        }
        return counter;
    }
%>

<jsp:include page="global/header.jsp" flush="true" />
<%@ page import="java.util.Map" %>
<%@ page import="org.codehaus.jackson.map.ObjectMapper" %>

<%
    // we have session service running AND this was a post, 
    // then modify URL to include session service id so bookmarking will work
    if (useSessionServiceBookmark && "POST".equals(request.getMethod())) {
%>
    <script>
        changeURLToSessionServiceURL(window.location.href, 
            window.location.pageTitle, 
            <%= new ObjectMapper().writeValueAsString(request.getParameterMap()) %>);
   </script>
<% } // end if isPost and we have session service running %>

<div class='main_smry'>
    <div id='main_smry_stat_div' style='float:right;margin-right:15px;margin-bottom:-5px;width:50%;text-align:right;'></div>
    <div id='main_smry_info_div'>
        <table style='margin-left:0px;width:40%;margin-top:-10px;margin-bottom:-5px;' >
            <tr>
                <td><div id='main_smry_modify_query_btn'><div></td>
                <td><div id='main_smry_query_div' style='padding-left: 5px;'></div></td>
            </tr>
        </table>
    </div>
    <div style="margin-left:5px;display:none;margin-top:-5px;" id="query_form_on_results_page">
        <%@ include file="query_form.jsp" %>
    </div>
</div>

<div id="tabs">
    <ul>
    <%
        Boolean showMutTab = false;
        Boolean showCancerTypesSummary = false;
        Boolean showEnrichmentsTab = true;
        Boolean showSurvivalTab = true;
        Boolean showPlotsTab = true;
        Boolean showDownloadTab = true;
        Boolean showBookmarkTab = true;
        List<String> disabledTabs = GlobalProperties.getDisabledTabs();

            Enumeration paramEnum = request.getParameterNames();
            StringBuffer buf = new StringBuffer(request.getAttribute(QueryBuilder.ATTRIBUTE_URL_BEFORE_FORWARDING) + "?");

            while (paramEnum.hasMoreElements())
            {
                String paramName = (String) paramEnum.nextElement();
                String values[] = request.getParameterValues(paramName);

                if (values != null && values.length >0)
                {
                    for (int i=0; i<values.length; i++)
                    {
                        String currentValue = values[i].trim();

                        if (currentValue.contains("mutation") && !disabledTabs.contains("mutations"))
                        {
                            showMutTab = true;
                        }                        
                        if (disabledTabs.contains("co_expression")) 
                        {
                            showCoexpTab = false;
                        }                        
                        if (disabledTabs.contains("IGV")) 
                        {
                            showIGVtab = false;
                        }                        
                        if (disabledTabs.contains("mutual_exclusivity")) 
                        {
                            computeLogOddsRatio = false;
                        }                        
                        if (disabledTabs.contains("enrichments")) 
                        {
                            showEnrichmentsTab = false;
                        }                        
                        if (disabledTabs.contains("survival")) 
                        {
                            has_survival = false;
                        }                        
                        if (disabledTabs.contains("network")) 
                        {
                            includeNetworks = false;
                        }                        
                        if (disabledTabs.contains("plots")) 
                        {
                            showPlotsTab = false;
                        }
                        if (disabledTabs.contains("download")) 
                        {
                            showDownloadTab = false;
                        }
                        if (disabledTabs.contains("bookmark")) {
                            showBookmarkTab = false;
                        }
                        
                        if (paramName.equals(QueryBuilder.GENE_LIST)
                            && currentValue != null)
                        {
                            //  Spaces must be converted to semis
                            currentValue = Utilities.appendSemis(currentValue);
                            //  Extra spaces must be removed.  Otherwise OMA Links will not work.
                            currentValue = currentValue.replaceAll("\\s+", " ");
                            //currentValue = URLEncoder.encode(currentValue);
                        }
                        else if (paramName.equals(QueryBuilder.CASE_IDS) ||
                                paramName.equals(QueryBuilder.CLINICAL_PARAM_SELECTION))
                        {
                            // do not include case IDs anymore (just skip the parameter)
                            // if we need to support user-defined case lists in the future,
                            // we need to replace this "parameter" with the "attribute" caseIdsKey

                            // also do not include clinical param selection parameter, since
                            // it is only related to user-defined case sets, we need to take care
                            // of unsafe characters such as '<' and '>' if we decide to add this
                            // parameter in the future
                            continue;
                        }

                        // this is required to prevent XSS attacks
                        currentValue = xssUtil.getCleanInput(currentValue);
                        //currentValue = StringEscapeUtils.escapeJavaScript(currentValue);
                        //currentValue = StringEscapeUtils.escapeHtml(currentValue);
                        currentValue = URLEncoder.encode(currentValue);

                        buf.append (paramName + "=" + currentValue + "&");
                    }
                }
            }

            // determine whether to show the cancerTypesSummaryTab
            // retrieve the cancerTypesMap and create an iterator for the values
            Map<String, List<String>>  cancerTypesMap = (Map<String, List<String>>) request.getAttribute(QueryBuilder.CANCER_TYPES_MAP);
            if(cancerTypesMap.keySet().size() > 1) {
            	showCancerTypesSummary = true;
            }
            else if (cancerTypesMap.keySet().size() == 1 && cancerTypesMap.values().iterator().next().size() > 1 )  {
            	showCancerTypesSummary = true;
            }
            if (disabledTabs.contains("cancer_types_summary")) {
                showCancerTypesSummary = false;
            }
            out.println ("<li><a href='#summary' class='result-tab' id='oncoprint-result-tab'>OncoPrint</a></li>");
            // if showCancerTypesSummary is try, add the list item
            if(showCancerTypesSummary){
                out.println ("<li><a href='#pancancer_study_summary' class='result-tab' title='Cancer types summary'>"
                + "Cancer Types Summary</a></li>");
            }

            if (computeLogOddsRatio) {
                out.println ("<li><a href='#mutex' class='result-tab' id='mutex-result-tab'>"
                + "Mutual Exclusivity</a></li>");
            }
            if (showPlotsTab) {
                out.println ("<li><a href='#plots' class='result-tab' id='plots-result-tab'>Plots</a></li>");
            }            
            if (showMutTab){
                out.println ("<li><a href='#mutation_details' class='result-tab' id='mutation-result-tab'>Mutations</a></li>");
            }
            if (showCoexpTab) {
                out.println ("<li><a href='#coexp' class='result-tab' id='coexp-result-tab'>Co-Expression</a></li>");
            }
            if (has_mrna || has_copy_no || showMutTab && showEnrichmentsTab) {
                out.println("<li><a href='#enrichementTabDiv' id='enrichments-result-tab' class='result-tab'>Enrichments</a></li>");
            }
            if (has_survival) {
                out.println ("<li><a href='#survival' class='result-tab' id='survival-result-tab'>Survival</a></li>");
            }
            if (includeNetworks) {
                out.println ("<li><a href='#network' class='result-tab' id='network-result-tab'>Network</a></li>");
            }
            if (showIGVtab){
                out.println ("<li><a href='#igv_tab' class='result-tab' id='igv-result-tab'>CN Segments</a></li>");
            }
            if (showDownloadTab) {
                out.println ("<li><a href='#data_download' class='result-tab' id='data-download-result-tab'>Download</a></li>");
            }       
            if (showBookmarkTab) {
                out.print ("<li><a href='#bookmark_email' class='result-tab' id='bookmark-result-tab'");
                if (useSessionServiceBookmark) {
                    out.print (" data-session='");
	                out.print (new ObjectMapper().writeValueAsString(request.getParameterMap()));
	                out.print ("'");
                } 
	            out.println (">Bookmark</a></li>");
            }            
            out.println ("</ul>");

            out.println ("<div class=\"section\" id=\"bookmark_email\">");

            if (!useSessionServiceBookmark && sampleSetId.equals("-1"))
            {
                out.println("<br>");
                out.println("<h4>The bookmark option is not available for user-defined case lists.</h4>");
            } 
            else 
            {
                out.println ("<h4>Right click on one of the links below to bookmark your results:</h4>");
                out.println("<br>");
                out.println("<div id='session-id'></div>");
                out.println("<br>");
                out.println("If you would like to use a <b>shorter URL that will not break in email postings</b>, you can use the<br><a href='https://bitly.com/'>bitly.com</a> url below:<BR>");
                out.println("<div id='bitly'></div>");
            }
            out.println("</div>");
    %>

        <div class="section" id="summary">
            <% //contents of fingerprint.jsp now come from attribute on request object %>
            <%@ include file="oncoprint/main.jsp" %>
        </div>

        <!-- if showCancerTypes is true, include cancer_types_summary.jsp -->
        <% if(showCancerTypesSummary) { %>
        <%@ include file="pancancer_study_summary.jsp" %>
        <%}%>

        <%@ include file="plots_tab.jsp" %>

        <% if (showIGVtab) { %>
            <%@ include file="igv.jsp" %>
        <% } %>

        <% if (has_survival) { %>
            <%@ include file="survival_tab.jsp" %>
        <% } %>

        <% if (computeLogOddsRatio) { %>
            <%@ include file="mutex_tab.jsp" %>
        <% } %>

        <% if (mutationDetailLimitReached != null) {
            out.println("<div class=\"section\" id=\"mutation_details\">");
            out.println("<P>To retrieve mutation details, please specify "
            + QueryBuilder.MUTATION_DETAIL_LIMIT + " or fewer genes.<BR>");
            out.println("</div>");
        } else if (showMutTab) { %>
            <%@ include file="mutation_views.jsp" %>
            <%@ include file="mutation_details.jsp" %>
        <%  } %>

        <% if (includeNetworks) { %>
            <%@ include file="networks.jsp" %>
        <% } %>

        <% if (showCoexpTab) { %>
            <%@ include file="co_expression.jsp" %>
        <% } %>

        <% if (has_mrna || has_copy_no || showMutTab) { %>
            <%@ include file="enrichments_tab.jsp" %>
        <% } %>

        <%@ include file="data_download.jsp" %>

</div> <!-- end tabs div -->


</div>
</td>
</tr>
<tr>
    <td colspan="3">
        <jsp:include page="global/footer.jsp" flush="true" />
    </td>
</tr>
</table>
</center>
</div>
<jsp:include page="global/xdebug.jsp" flush="true" />
</form>

<script type="text/javascript">
    // it is better to check selected tab after document gets ready
    $(document).ready(function() {
        var firstTime = true;

        $("#toggle_query_form").tipTip();
        // check if network tab is initially selected
        if ($("div.section#network").is(":visible"))
        {
            // init the network tab
	        //send2cytoscapeweb(window.networkGraphJSON, "cytoscapeweb", "network");
	        //firstTime = false;

	        // TODO window.networkGraphJSON is null at this point,
	        // this is a workaround to wait for graphJSON to get ready
	        var interval = setInterval(function() {
		        if (window.networkGraphJSON != null)
		        {
			        clearInterval(interval);
			        if (firstTime)
			        {
                $(window).resize();
				        send2cytoscapeweb(window.networkGraphJSON, "cytoscapeweb", "network");
				        firstTime = false;
			        }
		        }
	        }, 50);
        }

        $("a.result-tab").click(function(){

            if($(this).attr("href")=="#network")
            {
              var interval = setInterval(function() {
                if (window.networkGraphJSON != null)
                {
                  clearInterval(interval);
                  if(firstTime)
                  {
                    $(window).resize();
                    send2cytoscapeweb(window.networkGraphJSON, "cytoscapeweb", "network");
                    firstTime = false;
                  }
                else
                  {
                    // TODO this is a workaround to adjust cytoscape canvas
                    // and probably not the best way to do it...
                    $(window).resize();
                  }

                }
              }, 50);
            }
        });

        $("#bookmark-result-tab").parent().click(function() {
            <% if (useSessionServiceBookmark) { %>
                addSessionServiceBookmark(window.location.href, $(this).children("#bookmark-result-tab").data('session'));
            <% } else { %>
                addURLBookmark();
            <% } %>
        });

        //qtips
        $("#oncoprint-result-tab").qtip(
            {
                content: {text: "Compact visualization of genomic alterations"},
                style: { classes: 'qtip-light qtip-rounded qtip-shadow qtip-lightyellow result-tab-qtip-content' },
                show: {event: "mouseover", delay: 0},
                hide: {fixed:true, delay: 100, event: "mouseout"},
                position: {my:'left top',at:'right bottom', viewport: $(window)}
            }
        );
        $("#oncoprint-result-tab").click(function() {
            $(window).trigger('resize');
        });
        $("#mutex-result-tab").qtip(
            {
                content: {text: "Mutual exclusivity and co-occurrence analysis"},
                style: { classes: 'qtip-light qtip-rounded qtip-shadow qtip-lightyellow result-tab-qtip-content' },
                show: {event: "mouseover", delay: 0},
                hide: {fixed:true, delay: 100, event: "mouseout"},
                position: {my:'left top',at:'right bottom', viewport: $(window)}
            }
        );
        $("#plots-result-tab").qtip(
            {
                content: {text: "Multiple plots, including CNA v. mRNA expression"},
                style: { classes: 'qtip-light qtip-rounded qtip-shadow qtip-lightyellow result-tab-qtip-content' },
                show: {event: "mouseover", delay: 0},
                hide: {fixed:true, delay: 100, event: "mouseout"},
                position: {my:'left top',at:'right bottom', viewport: $(window)}
            }
        );
        $("#mutation-result-tab").qtip(
            {
                content: {text: "Mutation details, including mutation type, amino acid change, validation status and predicted functional consequence"},
                style: { classes: 'qtip-light qtip-rounded qtip-shadow qtip-lightyellow result-tab-qtip-content' },
                show: {event: "mouseover", delay: 0},
                hide: {fixed:true, delay: 100, event: "mouseout"},
                position: {my:'left top',at:'right bottom', viewport: $(window)}
            }
        );
        $("#coexp-result-tab").qtip(
            {
                content: {text: "List of top co-expressed genes"},
                style: { classes: 'qtip-light qtip-rounded qtip-shadow qtip-lightyellow result-tab-qtip-content' },
                show: {event: "mouseover", delay: 0},
                hide: {fixed:true, delay: 100, event: "mouseout"},
                position: {my:'left top',at:'right bottom', viewport: $(window)}
            }
        );
        $("#enrichments-result-tab").qtip(
            {
                content: {text: "This analysis finds alterations " +
                "(mutations, copy number alterations, mRNA expression changes, and protein expression changes, if available) " +
                "that are enriched in either altered samples (with at least one alteration based on query) or unaltered samples. "},
                //"The analysis is only performed on annotated cancer genes. <a href='cancer_gene_list.jsp' target='_blank'>[List of Portal Cancer Genes]</a>"},
                style: { classes: 'qtip-light qtip-rounded qtip-shadow qtip-lightyellow result-tab-qtip-content' },
                show: {event: "mouseover", delay: 0},
                hide: {fixed:true, delay: 100, event: "mouseout"},
                position: {my:'left top',at:'right bottom', viewport: $(window)}
            }
        );
        $("#survival-result-tab").qtip(
            {
                content: {text: "Survival analysis and Kaplan-Meier curves"},
                style: { classes: 'qtip-light qtip-rounded qtip-shadow qtip-lightyellow result-tab-qtip-content' },
                show: {event: "mouseover", delay: 0},
                hide: {fixed:true, delay: 100, event: "mouseout"},
                position: {my:'left top',at:'right bottom', viewport: $(window)}
            }
        );
        $("#network-result-tab").qtip(
            {
                content: {text: "Network visualization and analysis"},
                style: { classes: 'qtip-light qtip-rounded qtip-shadow qtip-lightyellow result-tab-qtip-content' },
                show: {event: "mouseover", delay: 0},
                hide: {fixed:true, delay: 100, event: "mouseout"},
                position: {my:'left top',at:'right bottom', viewport: $(window)}
            }
        );
        $("#igv-result-tab").qtip(
            {
                content: {text: "Visualize copy number data via the Integrative Genomics Viewer (IGV)"},
                style: { classes: 'qtip-light qtip-rounded qtip-shadow qtip-lightyellow result-tab-qtip-content' },
                show: {event: "mouseover", delay: 0},
                hide: {fixed:true, delay: 100, event: "mouseout"},
                position: {my:'left top',at:'right bottom', viewport: $(window)}
            }
        );
        $("#data-download-result-tab").qtip(
            {
                content: {text: "Download all alterations or copy and paste into Excel"},
                style: { classes: 'qtip-light qtip-rounded qtip-shadow qtip-lightyellow result-tab-qtip-content' },
                show: {event: "mouseover", delay: 0},
                hide: {fixed:true, delay: 100, event: "mouseout"},
                position: {my:'left top',at:'right bottom', viewport: $(window)}
            }
        );
        $("#bookmark-result-tab").qtip(
            {
                content: {text: "Bookmark or generate a URL for email"},
                style: { classes: 'qtip-light qtip-rounded qtip-shadow qtip-lightyellow result-tab-qtip-content' },
                show: {event: "mouseover", delay: 0},
                hide: {fixed:true, delay: 100, event: "mouseout"},
                position: {my:'left top',at:'right bottom', viewport: $(window)}
            }
        );
    });
</script>


<style type="text/css">
    input[type="checkbox"]  {
        margin: 5px;
    }
    input[type="radio"]  {
        margin: 3px;
    }
    button {
        margin: 3px;
    }
    [class*="ui-button-text"] {
        margin: 3px;
    }
    .result-tab-qtip-content{
        font-size: 13px;
        line-height: 110%;
    }
</style>

</body>
</html>
