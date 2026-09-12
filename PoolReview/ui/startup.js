(function () {
    'use strict';
    function startPoolingWorkspace() {
        if (window.PoolReviewWorkspace) window.PoolReviewWorkspace.start();
    }
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', startPoolingWorkspace, { once: true });
    } else {
        startPoolingWorkspace();
    }
}());

