//
//  MangaThumbnailSkeletonView.swift
//  Smuggler
//
//  Created by mk.pwnz on 24/06/2022.
//

import SwiftUI

struct MangaThumbnailSkeletonView: View {
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.theme.darkGray)
            
            HStack(alignment: .top) {
                coverArtSkeleton
                
                VStack(alignment: .leading, spacing: 10) {
                    titleSkeleton
                    
                    statisticsSkeleton
                    
                    descriptionSkeleton
                }
            }
            .padding(10)
        }
        .frame(height: 150)
    }
}

struct MangaThumbnailSkeletonView_Previews: PreviewProvider {
    static var previews: some View {
        MangaThumbnailSkeletonView()
    }
}

extension MangaThumbnailSkeletonView {
    private var coverArtSkeleton: some View {
        Color.black
            .opacity(0.45)
            .redacted(reason: .placeholder)
            .frame(width: 100, height: 150)
            .cornerRadius(10)
    }
    
    private var titleSkeleton: some View {
        Text(String.placeholder(length: 25))
            .lineLimit(2)
            .foregroundColor(.white)
            .font(.headline)
            .redacted(reason: .placeholder)
    }
    
    private var statisticsSkeleton: some View {
        HStack(alignment: .top, spacing: 10) {
            HStack(alignment: .top, spacing: 0) {
                Image(systemName: "star.fill")
                
                Text(String.placeholder(length: 4))
                    .redacted(reason: .placeholder)
            }
            
            HStack(alignment: .top, spacing: 0) {
                Image(systemName: "bookmark.fill")
                
                Text(String.placeholder(length: 7))
                    .redacted(reason: .placeholder)
            }
        }
        .font(.footnote)
    }
    
    private var descriptionSkeleton: some View {
        VStack {
            ForEach(0..<5) { _ in
                Text(String.placeholder(length: 50))
                    .foregroundColor(.white)
                    .font(.footnote)
                    .redacted(reason: .placeholder)
            }
        }
    }
}
