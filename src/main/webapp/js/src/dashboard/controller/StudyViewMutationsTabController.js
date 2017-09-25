  

var StudyViewMutationsTabController = (function() {
    var init = function(callback) {
        StudyViewProxy.getMutatedGenesData()
            .then(function(data) {
                StudyViewInitMutationsTab.init(data);
                if(_.isFunction(callback)) {
                    callback();
                }
            });
    };

    return {
        init: init,
        getDataTable: function() {
            return StudyViewInitMutationsTab.getDataTable();
        }
    };
})();